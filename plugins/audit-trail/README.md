# audit-trail

Comprehensive security event logging with rotation and reporting.

## Install

Part of the [Hydra](../..) bundle. The simplest install is the `full` meta-plugin, which pulls in all 5 Hydra plugins via dependency resolution:

```
/plugin marketplace add enchanter-ai/hydra
/plugin install full@hydra
```

To install this plugin on its own: `/plugin install hydra-audit-trail@hydra`. `audit-trail` only has events to log because `secret-scanner`, `vuln-detector`, `action-guard`, and `config-shield` emit them. On its own, you get an empty JSONL file and a report with no findings.

## Algorithm
- **R8: EMA Posture Decay** — cross-session EMA of threat rates (α=0.3)

## Hook
- **PostToolUse** on ALL tools — logs every tool use for compliance and review

## Logging Format
JSONL entries in `state/audit.jsonl`:
```json
{"event":"tool_use","ts":"2026-04-15T14:23:00Z","tool":"Write","target":"src/app.py"}
{"event":"secret_detected","ts":"...","file":"...","pattern_id":"aws-access-key-id","severity":"critical","masked":"AKIA...MPLE"}
{"event":"action_blocked","ts":"...","reason":"rm -rf /","severity":"critical"}
```

## Features
- JSONL append with atomic mkdir locks
- 10MB rotation (keeps last 1000 entries)
- Dark-themed HTML report generation
- Cross-session learning via EMA
- HMAC hash chain for tamper evidence (`scripts/chain-helpers.sh`)
- OTLP/JSON exporter for Datadog/Sentry observability (`scripts/otel-exporter.py`)

## OTLP Export — Datadog / Sentry bridge

Closes audit findings **F-021** (OTLP traces) and **F-024** (Sentry / Datadog
LLM Observability parity) from the security closure synthesis. The local
HMAC chain is forensically sound but offline; production deployments stream
spans into a real observability backend.

The exporter is stdlib-only — **no OpenTelemetry SDK dependency** — so it
runs in air-gapped environments. It emits OTLP/JSON; the operator's
collector handles protobuf encoding and vendor routing.

```bash
# follow mode — stream new audit events into a local OTLP/HTTP collector
python scripts/otel-exporter.py state/audit.jsonl --follow \
  | curl -s -XPOST http://localhost:4318/v1/traces \
         -H 'content-type: application/json' --data-binary @-
```

Span fields (per closure F-021/F-024): `agent.id`, `tool.name`,
`tool.duration_ms`, `tool.bytes_in/out`, `network.dest_host`,
`policy.outcome`, `error.type`, `trace_id` (derived from `prev_hash` when
absent so forensic correlation back to `state/audit.jsonl` stays
joinable), `span_id` (UUID v4).

**Required env vars:** `DD_API_KEY`, `SENTRY_DSN`,
`OTEL_EXPORTER_OTLP_ENDPOINT`. Sample collector config with Datadog +
Sentry pipelines: [`scripts/otel-config.example.yaml`](scripts/otel-config.example.yaml).

**Limitation:** JSON only — protobuf encoding is the operator's collector's
job. This is the deliberate offline-first tradeoff.

See the `audit-otlp` skill for an interactive walkthrough.

## Command
`/hydra:audit` — event timeline, severity filters, report generation

## Agent
`chronicler` (Haiku) — session security summary and posture analysis

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
