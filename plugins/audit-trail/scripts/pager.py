#!/usr/bin/env python3
"""Audit-trail pager — F-011 closure.

Reads new rows from state/audit.jsonl, classifies by severity, and routes
HIGH/CRITICAL events to an operator-configured webhook (PagerDuty, Opsgenie,
Slack, generic). Failure-mode: fail-open. If the webhook is unreachable,
the event is appended to state/paging-undelivered.jsonl with a retry counter.

Stdlib only. Atomic state writes. Advisory contract — paging is observability,
not a gate.

Config: state/paging-config.json (see paging-config.example.json).
Cursor: state/paging-cursor.json — tracks last-read byte offset of audit.jsonl.

Severity ranking: DEBUG < INFO < LOW < MEDIUM < HIGH < CRITICAL.
Default min_severity: HIGH.

Rate limit: token bucket per minute. Suppressed events are NOT enqueued to
undelivered.jsonl — suppression is intentional (rate-limit), not a delivery
failure.

Usage:
    pager.py                     # process new audit rows
    pager.py --retry             # retry undelivered events
    pager.py --dry-run           # parse + classify, no webhook send
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path
from typing import Any

SEVERITY_RANK = {
    "DEBUG": 0,
    "INFO": 1,
    "LOW": 2,
    "MEDIUM": 3,
    "HIGH": 4,
    "CRITICAL": 5,
}

SCRIPT_DIR = Path(__file__).resolve().parent
PLUGIN_ROOT = SCRIPT_DIR.parent
STATE_DIR = PLUGIN_ROOT / "state"
AUDIT_LOG = STATE_DIR / "audit.jsonl"
CONFIG_PATH = STATE_DIR / "paging-config.json"
CURSOR_PATH = STATE_DIR / "paging-cursor.json"
UNDELIVERED_PATH = STATE_DIR / "paging-undelivered.jsonl"
RUN_LOG = STATE_DIR / "paging-runs.log"

DEFAULT_CONFIG = {
    "enabled": False,
    "webhook_url": "",
    "min_severity": "HIGH",
    "rate_limit_per_min": 5,
    "timeout_seconds": 5,
    "max_retries": 3,
}


def log(line: str) -> None:
    """Append a single log line to RUN_LOG. Never raises."""
    try:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        with RUN_LOG.open("a", encoding="utf-8") as fh:
            ts = time.strftime("%Y-%m-%dT%H:%M:%S")
            fh.write(f"[{ts}] {line}\n")
    except Exception:
        # Logger must never break the pager.
        pass


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    """Write JSON via tmp + rename. Caller handles existence."""
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    tmp.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    tmp.replace(path)


def append_jsonl(path: Path, row: dict[str, Any]) -> None:
    """Append one JSON line. POSIX append is atomic for small lines."""
    path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(row, separators=(",", ":")) + "\n"
    with path.open("a", encoding="utf-8") as fh:
        fh.write(line)


def load_config() -> dict[str, Any]:
    """Load paging config. Returns DEFAULT_CONFIG if absent."""
    if not CONFIG_PATH.exists():
        return dict(DEFAULT_CONFIG)
    try:
        cfg = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        log(f"config-load-failed err={exc!r} — using defaults")
        return dict(DEFAULT_CONFIG)
    merged = dict(DEFAULT_CONFIG)
    merged.update({k: v for k, v in cfg.items() if k in DEFAULT_CONFIG})
    return merged


def load_cursor() -> int:
    if not CURSOR_PATH.exists():
        return 0
    try:
        data = json.loads(CURSOR_PATH.read_text(encoding="utf-8"))
        return int(data.get("offset", 0))
    except (OSError, json.JSONDecodeError, ValueError):
        return 0


def save_cursor(offset: int) -> None:
    atomic_write_json(CURSOR_PATH, {"offset": offset, "updated": time.time()})


def severity_of(row: dict[str, Any]) -> str:
    """Extract severity, normalised to upper-case. Defaults to INFO."""
    raw = row.get("severity") or row.get("level") or "INFO"
    s = str(raw).strip().upper()
    return s if s in SEVERITY_RANK else "INFO"


def should_page(row: dict[str, Any], min_severity: str) -> bool:
    floor = SEVERITY_RANK.get(min_severity.upper(), SEVERITY_RANK["HIGH"])
    return SEVERITY_RANK[severity_of(row)] >= floor


def read_new_rows(start_offset: int) -> tuple[list[dict[str, Any]], int]:
    """Read JSONL rows from start_offset onward. Returns (rows, new_offset).

    Malformed lines are skipped and logged but do not abort processing.
    """
    if not AUDIT_LOG.exists():
        return [], start_offset
    rows: list[dict[str, Any]] = []
    with AUDIT_LOG.open("rb") as fh:
        size = fh.seek(0, os.SEEK_END)
        if start_offset > size:
            # Log truncated/rotated — re-read from start.
            log(f"cursor-past-eof start={start_offset} size={size} — resetting")
            start_offset = 0
        fh.seek(start_offset)
        raw = fh.read()
        new_offset = start_offset + len(raw)
    text = raw.decode("utf-8", errors="replace")
    for lineno, line in enumerate(text.splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError as exc:
            log(f"malformed-row offset~{start_offset} line={lineno} err={exc.msg}")
    return rows, new_offset


def post_webhook(url: str, payload: dict[str, Any], timeout: int) -> tuple[bool, str]:
    """POST JSON to url. Returns (ok, error_msg)."""
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={"Content-Type": "application/json", "User-Agent": "hydra-audit-pager/1"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            status = resp.status
            if 200 <= status < 300:
                return True, f"status={status}"
            return False, f"status={status}"
    except urllib.error.URLError as exc:
        return False, f"urlerror:{exc.reason!r}"
    except (TimeoutError, OSError) as exc:
        return False, f"oserror:{exc!r}"
    except Exception as exc:  # noqa: BLE001 — fail-open advisory contract
        return False, f"unexpected:{exc!r}"


def build_payload(row: dict[str, Any], page_id: str) -> dict[str, Any]:
    """Compose webhook payload. Generic shape — fits Slack/PagerDuty/Opsgenie."""
    sev = severity_of(row)
    return {
        "page_id": page_id,
        "source": "hydra/audit-trail",
        "severity": sev,
        "summary": row.get("summary") or row.get("event") or row.get("type") or "audit-event",
        "event": row,
        "ts": row.get("ts") or row.get("timestamp") or time.time(),
    }


def page_event(
    row: dict[str, Any],
    cfg: dict[str, Any],
    *,
    dry_run: bool,
) -> tuple[bool, str, dict[str, Any]]:
    """Send one page. Returns (delivered, info, payload)."""
    page_id = str(uuid.uuid4())
    payload = build_payload(row, page_id)
    if dry_run:
        return True, "dry-run", payload
    if not cfg.get("enabled"):
        return False, "paging-disabled", payload
    url = cfg.get("webhook_url") or ""
    if not url:
        return False, "no-webhook-url", payload
    ok, info = post_webhook(url, payload, int(cfg.get("timeout_seconds", 5)))
    return ok, info, payload


def process_audit_log(*, dry_run: bool = False) -> dict[str, Any]:
    """Main loop: scan new audit rows, page on HIGH+, persist cursor."""
    cfg = load_config()
    start = load_cursor()
    rows, new_offset = read_new_rows(start)
    min_sev = cfg.get("min_severity", "HIGH")
    rate_limit = int(cfg.get("rate_limit_per_min", 5))

    summary = {
        "scanned": len(rows),
        "matched": 0,
        "delivered": 0,
        "undelivered": 0,
        "rate_limited": 0,
        "from_offset": start,
        "to_offset": new_offset,
        "dry_run": dry_run,
    }

    sent_this_minute = 0
    minute_window_start = time.time()

    for row in rows:
        if not should_page(row, min_sev):
            continue
        summary["matched"] += 1

        # Reset minute window if expired.
        now = time.time()
        if now - minute_window_start >= 60:
            sent_this_minute = 0
            minute_window_start = now

        if sent_this_minute >= rate_limit:
            summary["rate_limited"] += 1
            log(f"rate-limited severity={severity_of(row)} window_start={minute_window_start:.0f}")
            continue

        ok, info, payload = page_event(row, cfg, dry_run=dry_run)
        if ok:
            summary["delivered"] += 1
            sent_this_minute += 1
            log(f"page-sent id={payload['page_id']} severity={payload['severity']} info={info}")
        else:
            summary["undelivered"] += 1
            undelivered_row = {
                "page_id": payload["page_id"],
                "ts": time.time(),
                "reason": info,
                "retry_count": 0,
                "payload": payload,
            }
            append_jsonl(UNDELIVERED_PATH, undelivered_row)
            log(f"page-undelivered id={payload['page_id']} reason={info}")

    save_cursor(new_offset)
    return summary


def retry_undelivered() -> dict[str, Any]:
    """Retry rows in undelivered.jsonl. Successful retries are dropped from the file.

    Atomic strategy: read all rows, partition into delivered/still-undelivered,
    rewrite the file atomically.
    """
    cfg = load_config()
    summary = {"retried": 0, "delivered": 0, "still_undelivered": 0, "exhausted": 0}
    if not UNDELIVERED_PATH.exists():
        return summary

    max_retries = int(cfg.get("max_retries", 3))
    timeout = int(cfg.get("timeout_seconds", 5))
    url = cfg.get("webhook_url") or ""

    surviving: list[str] = []
    with UNDELIVERED_PATH.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                surviving.append(line)
                continue
            summary["retried"] += 1
            row["retry_count"] = int(row.get("retry_count", 0)) + 1

            if not cfg.get("enabled") or not url:
                # Cannot retry — keep as-is, do not bump count further.
                row["retry_count"] -= 1
                surviving.append(json.dumps(row, separators=(",", ":")))
                summary["still_undelivered"] += 1
                continue

            if row["retry_count"] > max_retries:
                summary["exhausted"] += 1
                log(f"page-retry-exhausted id={row.get('page_id')} retries={row['retry_count']}")
                # Drop — exhausted entries are removed from the queue.
                continue

            ok, info = post_webhook(url, row.get("payload", {}), timeout)
            if ok:
                summary["delivered"] += 1
                log(f"page-retry-ok id={row.get('page_id')} info={info}")
            else:
                summary["still_undelivered"] += 1
                surviving.append(json.dumps(row, separators=(",", ":")))
                log(f"page-retry-failed id={row.get('page_id')} reason={info}")

    # Atomic rewrite.
    tmp = UNDELIVERED_PATH.with_suffix(UNDELIVERED_PATH.suffix + f".tmp.{os.getpid()}")
    if surviving:
        tmp.write_text("\n".join(surviving) + "\n", encoding="utf-8")
        tmp.replace(UNDELIVERED_PATH)
    else:
        # Empty queue — remove the file.
        try:
            UNDELIVERED_PATH.unlink()
        except FileNotFoundError:
            pass
    return summary


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Hydra audit-trail pager (F-011).")
    parser.add_argument("--retry", action="store_true", help="Retry undelivered events.")
    parser.add_argument("--dry-run", action="store_true", help="Classify only — never POST.")
    args = parser.parse_args(argv)

    try:
        if args.retry:
            result = retry_undelivered()
        else:
            result = process_audit_log(dry_run=args.dry_run)
    except Exception as exc:  # noqa: BLE001 — fail-open
        log(f"pager-fatal err={exc!r}")
        # Advisory contract: never propagate failure.
        print(json.dumps({"ok": False, "error": repr(exc)}))
        return 0

    print(json.dumps({"ok": True, "summary": result}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
