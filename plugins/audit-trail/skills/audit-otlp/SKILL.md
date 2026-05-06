---
name: audit-otlp
description: >
  Streams audit-trail events to OTLP-compatible backends (Datadog LLM
  Observability, Sentry AI Agent Monitoring) with full span fields per
  closure F-021/F-024. Use when the developer asks "how do I send audit
  events to Datadog/Sentry?", sets up production observability, wires
  an OTLP collector, or asks about exporting tool/policy spans.
  Auto-triggers on: "send audit to datadog", "sentry ai monitoring",
  "otlp exporter", "audit observability", "ship audit events",
  "production observability for hydra", "F-021", "F-024".
allowed-tools:
  - Read
  - Bash
---

<purpose>
Bridge audit-trail's local HMAC-chained NDJSON to Sentry/Datadog-grade
observability via OTLP/JSON spans. Closes audit findings F-021 + F-024.
The exporter is stdlib-only — no OpenTelemetry SDK dep — so the operator
can run it in air-gapped environments and let their own collector handle
protobuf encoding and vendor routing.
</purpose>

<constraints>
1. Read-only on audit.jsonl. The exporter never mutates the source log.
2. Do NOT install the opentelemetry-sdk pip package. The exporter emits
   OTLP/JSON; the operator's collector translates to wire format.
3. Each emitted span MUST carry trace_id (32 hex) and span_id (16 hex).
   When the source row lacks trace_id, derive it from prev_hash so the
   forensic chain stays joinable to the observability stream.
4. Never echo secret values into spans. The audit.jsonl source has
   already masked them; pass-through only.
5. Treat the OTLP collector config as operator-owned — surface the
   example, don't deploy it.
</constraints>

<decision_tree>
IF user asks "how do I send audit events to Datadog/Sentry":
  → Walk them through the three pieces:
    1. The exporter at scripts/otel-exporter.py (stdlib, offline-first)
    2. The example collector config at scripts/otel-config.example.yaml
    3. The required env vars (DD_API_KEY, SENTRY_DSN, OTEL_EXPORTER_OTLP_ENDPOINT)
  → Show the canonical pipe:
    python ${CLAUDE_PLUGIN_ROOT}/scripts/otel-exporter.py \
        ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl --follow \
      | curl -s -XPOST http://localhost:4318/v1/traces \
             -H 'content-type: application/json' --data-binary @-

IF user asks for a one-shot export (not follow mode):
  → Run:
    python "${CLAUDE_PLUGIN_ROOT}/scripts/otel-exporter.py" \
           "${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl"
  → Pipe the stdout into their collector or save to a file.

IF user asks "what fields does the span carry":
  → Quote the closure schema verbatim:
    agent.id, tool.name, tool.duration_ms, tool.bytes_in, tool.bytes_out,
    network.dest_host, policy.outcome, error.type, plus trace_id and
    span_id. Source-row prev_hash rides as audit.prev_hash for forensic
    correlation.

IF user asks to smoke-test the exporter:
  → Pipe a synthetic line through and confirm OTLP/JSON shape:
    echo '{"event":"tool_use","ts":"2026-04-15T14:23:00Z","tool":"Write","duration_ms":42,"bytes_in":120,"bytes_out":0,"prev_hash":"GENESIS","policy_outcome":"allowed"}' \
      | python "${CLAUDE_PLUGIN_ROOT}/scripts/otel-exporter.py" /dev/stdin
  → Confirm: top-level resourceSpans key, span has traceId/spanId,
    attributes include tool.name + policy.outcome.

IF audit.jsonl is empty:
  → Tell the operator: nothing to export yet; events accumulate as the
    PostToolUse hook fires.

IF the operator asks about protobuf encoding:
  → "The exporter emits OTLP/JSON. The OTLP collector handles protobuf
    encoding to the backend's wire format. This is a deliberate offline-
    first choice — no OpenTelemetry SDK dependency."
</decision_tree>

<output_format>
## OTLP Export Status

- **Exporter:** `scripts/otel-exporter.py`
- **Collector config:** `scripts/otel-config.example.yaml`
- **Source log:** `state/audit.jsonl` (HMAC-chained, R8 EMA-tracked)
- **Backends:** Datadog LLM Observability, Sentry AI Agent Monitoring
- **Closure:** F-021 (OTLP traces) + F-024 (Sentry/Datadog parity)

### Quick start
```
python scripts/otel-exporter.py state/audit.jsonl --follow \
  | curl -s -XPOST $OTEL_EXPORTER_OTLP_ENDPOINT/v1/traces \
         -H 'content-type: application/json' --data-binary @-
```

### Span fields
| Attribute | Source row field | Notes |
|-----------|------------------|-------|
| agent.id | agent_id / session_id | session correlator |
| tool.name | tool | Write/Edit/Bash/etc |
| tool.duration_ms | duration_ms | int |
| tool.bytes_in/out | bytes_in/out | int |
| network.dest_host | dest_host | only for net-touching |
| policy.outcome | policy_outcome | allowed/blocked/warn |
| error.type | error_type | exception class |
| trace_id | derived from prev_hash | 32 hex |
| span_id | UUID v4 (16 hex) | per span |
</output_format>

<failure_modes>
- F02 fabrication: never claim spans were delivered to Datadog/Sentry
  without seeing the collector's confirmation. The exporter only emits
  OTLP/JSON; delivery is the collector's contract.
- F08 tool mis-invocation: don't shell out to the opentelemetry-sdk
  Python package. The exporter is stdlib-only by design.
- F14 version drift: if the operator's Datadog Agent is older than v7.42
  it can't receive OTLP natively — point them at the datadog exporter
  block in otel-config.example.yaml as a fallback path.
</failure_modes>
