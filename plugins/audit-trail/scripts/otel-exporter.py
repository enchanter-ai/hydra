#!/usr/bin/env python3
"""otel-exporter — bridge audit-trail JSONL to OTLP-compatible spans.

Closes audit findings F-021 + F-024. The HMAC-chained NDJSON in
state/audit.jsonl is forensically sound but offline — production-grade
observability needs OTLP spans on every tool/hook/policy decision so
they land in Datadog LLM Observability, Sentry AI Agent Monitoring, or
any OTLP collector.

This exporter reads audit.jsonl (tail or full), translates each row to
an OTLP/JSON span, and emits one JSON object per line on stdout. The
operator pipes the stream into an OTLP collector (see
otel-config.example.yaml) which handles protobuf encoding and vendor
routing. We deliberately do NOT depend on the OpenTelemetry SDK —
offline-first, stdlib-only, easy to audit.

Usage
-----
    # one-shot: convert the whole log
    python otel-exporter.py state/audit.jsonl

    # follow mode: emit spans for new lines as they arrive
    python otel-exporter.py state/audit.jsonl --follow

    # pipe into a local OTLP/HTTP collector
    python otel-exporter.py state/audit.jsonl \\
        | curl -s -XPOST http://localhost:4318/v1/traces \\
               -H 'content-type: application/json' --data-binary @-

Span schema (per F-021/F-024 closure)
-------------------------------------
    agent.id            (string) — session/agent identifier
    tool.name           (string) — tool invoked
    tool.duration_ms    (int)    — elapsed wall time
    tool.bytes_in       (int)    — input payload size
    tool.bytes_out      (int)    — output payload size
    network.dest_host   (string) — only for network-touching tools
    policy.outcome      (string) — allowed | blocked | warn
    error.type          (string) — exception class / blocker reason
    trace_id            (32 hex) — derived from prev_hash if missing
    span_id             (16 hex) — UUID v4, lower 16 hex digits

Limitations
-----------
- JSON only; protobuf encoding is the operator's collector's job.
- One span per audit row; no span parenting beyond trace_id grouping.
- Best-effort field mapping when source row is missing fields.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import uuid
from typing import Any, Dict, Iterable, Iterator, Optional

# OTLP/JSON status codes — see opentelemetry-proto trace.proto.
STATUS_UNSET = 0
STATUS_OK = 1
STATUS_ERROR = 2

# Span kind: 1 = INTERNAL (tool execution inside the agent loop).
SPAN_KIND_INTERNAL = 1


def _trace_id_from_prev_hash(prev_hash: Optional[str]) -> str:
    """Derive a 32-hex-char W3C trace_id from the chain's prev_hash.

    OTLP/JSON expects trace_id as a 32-character hex string. prev_hash
    is base64(sha256(...)); we re-hash it to lift it back into hex and
    truncate to 32 chars. "GENESIS" gets a stable sentinel hash so the
    first chain entry doesn't get a brand-new trace each export.
    """
    seed = (prev_hash or "GENESIS").encode("utf-8")
    return hashlib.sha256(seed).hexdigest()[:32]


def _span_id() -> str:
    """16 lower-hex chars = 8 bytes, as OTLP/JSON requires."""
    return uuid.uuid4().hex[:16]


def _ts_to_unix_nano(ts: Optional[str]) -> int:
    """RFC3339 timestamp -> Unix nanoseconds. Falls back to 'now'."""
    if not ts:
        return int(time.time() * 1_000_000_000)
    # Best-effort parse: support the trailing-Z form audit-trail emits.
    try:
        # 2026-04-15T14:23:00Z  or  2026-04-15T14:23:00.123456Z
        normalized = ts.rstrip("Z")
        if "." in normalized:
            base, frac = normalized.split(".", 1)
            secs = time.mktime(time.strptime(base, "%Y-%m-%dT%H:%M:%S"))
            frac_ns = int(frac.ljust(9, "0")[:9])
            return int(secs * 1_000_000_000) + frac_ns
        secs = time.mktime(time.strptime(normalized, "%Y-%m-%dT%H:%M:%S"))
        return int(secs * 1_000_000_000)
    except (ValueError, OverflowError):
        return int(time.time() * 1_000_000_000)


def _attr(key: str, value: Any) -> Optional[Dict[str, Any]]:
    """OTLP/JSON attribute encoding. Returns None for absent values."""
    if value is None:
        return None
    if isinstance(value, bool):
        return {"key": key, "value": {"boolValue": value}}
    if isinstance(value, int):
        return {"key": key, "value": {"intValue": str(value)}}
    if isinstance(value, float):
        return {"key": key, "value": {"doubleValue": value}}
    return {"key": key, "value": {"stringValue": str(value)}}


def row_to_span(row: Dict[str, Any]) -> Dict[str, Any]:
    """Translate one audit row to one OTLP/JSON span object.

    The output shape follows opentelemetry-proto's ResourceSpans ->
    ScopeSpans -> Span hierarchy, but we emit one span per line for
    streaming. The collector groups them.
    """
    trace_id = row.get("trace_id") or _trace_id_from_prev_hash(row.get("prev_hash"))
    start_ns = _ts_to_unix_nano(row.get("ts"))
    duration_ms = int(row.get("duration_ms", 0) or 0)
    end_ns = start_ns + (duration_ms * 1_000_000 if duration_ms else 0)

    # Status: blocked actions and explicit errors → ERROR; everything else OK.
    policy_outcome = row.get("policy_outcome") or row.get("outcome")
    error_type = row.get("error_type") or row.get("error")
    if row.get("event") == "action_blocked" or error_type:
        status_code = STATUS_ERROR
        status_msg = error_type or row.get("reason") or "blocked"
    else:
        status_code = STATUS_OK
        status_msg = ""

    # Pick a human-readable span name.
    name = row.get("tool") or row.get("event") or "audit_event"

    raw_attrs = [
        _attr("agent.id", row.get("agent_id") or row.get("session_id")),
        _attr("tool.name", row.get("tool")),
        _attr("tool.duration_ms", duration_ms or None),
        _attr("tool.bytes_in", row.get("bytes_in")),
        _attr("tool.bytes_out", row.get("bytes_out")),
        _attr("network.dest_host", row.get("dest_host") or row.get("network_dest_host")),
        _attr("policy.outcome", policy_outcome),
        _attr("error.type", error_type),
        _attr("audit.event", row.get("event")),
        _attr("audit.severity", row.get("severity")),
        _attr("audit.target", row.get("target")),
        _attr("audit.prev_hash", row.get("prev_hash")),
    ]
    attributes = [a for a in raw_attrs if a is not None]

    span = {
        "traceId": trace_id,
        "spanId": _span_id(),
        "name": str(name),
        "kind": SPAN_KIND_INTERNAL,
        "startTimeUnixNano": str(start_ns),
        "endTimeUnixNano": str(end_ns),
        "attributes": attributes,
        "status": {"code": status_code, "message": status_msg},
    }

    return {
        "resourceSpans": [
            {
                "resource": {
                    "attributes": [
                        _attr("service.name", "hydra.audit-trail"),
                        _attr("service.namespace", "enchanter"),
                    ],
                },
                "scopeSpans": [
                    {
                        "scope": {"name": "hydra.audit-trail.otel-exporter"},
                        "spans": [span],
                    }
                ],
            }
        ]
    }


def iter_lines(path: str, follow: bool) -> Iterator[str]:
    """Yield non-empty lines from `path`. If follow=True, tail -F style."""
    with open(path, "r", encoding="utf-8") as fh:
        # Drain existing content first.
        for line in fh:
            line = line.rstrip("\n")
            if line:
                yield line
        if not follow:
            return
        # tail -F loop: poll for new content, handle truncation/rotation.
        while True:
            where = fh.tell()
            line = fh.readline()
            if not line:
                # Detect truncation/rotation: if file shrank, reopen.
                try:
                    if os.path.getsize(path) < where:
                        fh.close()
                        fh = open(path, "r", encoding="utf-8")
                        continue
                except OSError:
                    pass
                time.sleep(0.5)
                continue
            line = line.rstrip("\n")
            if line:
                yield line


def parse_rows(lines: Iterable[str]) -> Iterator[Dict[str, Any]]:
    """Parse each NDJSON line; skip malformed (with a stderr note)."""
    for n, line in enumerate(lines, start=1):
        try:
            yield json.loads(line)
        except json.JSONDecodeError as exc:
            print(f"otel-exporter: skipping malformed line {n}: {exc}", file=sys.stderr)
            continue


def main(argv: Optional[list] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Bridge audit-trail JSONL to OTLP/JSON spans (F-021/F-024).",
    )
    parser.add_argument("audit_jsonl", help="path to state/audit.jsonl")
    parser.add_argument("--follow", action="store_true",
                        help="tail the file forever (like tail -F)")
    args = parser.parse_args(argv)

    if not os.path.isfile(args.audit_jsonl):
        print(f"otel-exporter: file not found: {args.audit_jsonl}", file=sys.stderr)
        return 2

    out = sys.stdout
    try:
        for row in parse_rows(iter_lines(args.audit_jsonl, args.follow)):
            payload = row_to_span(row)
            out.write(json.dumps(payload, separators=(",", ":")))
            out.write("\n")
            out.flush()
    except KeyboardInterrupt:
        return 0
    except BrokenPipeError:
        # Operator's collector closed the pipe — clean exit.
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
