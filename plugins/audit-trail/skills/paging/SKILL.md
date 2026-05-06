---
name: paging
description: >
  Routes HIGH and CRITICAL audit-trail events to an operator-configured
  webhook (PagerDuty, Opsgenie, Slack, generic). Reads new rows from
  state/audit.jsonl since the last cursor and POSTs a generic event payload.
  Use when the developer asks about on-call paging, alert routing, webhook
  setup, audit-event escalation, or wants to verify F-011 closure.
  Auto-triggers on: "page on-call", "wire pager", "paging config",
  "alert routing", "F-011", "send HIGH events to", "configure webhook".
  Do not use for crafting the audit log itself (see audit-awareness) or
  for verifying chain integrity (see audit-verify).
allowed-tools:
  - Read
  - Bash
  - Edit
---

<purpose>
Operator-facing skill for the audit-trail pager. Helps wire the webhook,
verify config, run the pager manually, and inspect undelivered events.
</purpose>

<preconditions>
- state/audit.jsonl exists (created on first PostToolUse event).
- Operator has a JSON-POST webhook endpoint ready (PagerDuty, Opsgenie,
  Slack, or generic).
</preconditions>

<runbook>

## Step 1 — Initial setup

```bash
cd ${CLAUDE_PLUGIN_ROOT}
cp state/paging-config.example.json state/paging-config.json
# Edit state/paging-config.json:
#   - enabled: true
#   - webhook_url: <your endpoint>
#   - min_severity: HIGH (or CRITICAL for stricter routing)
```

`paging-config.json` is gitignored — keep your webhook URL local.

## Step 2 — Smoke test (dry-run)

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/pager.py --dry-run
```

Expected output: JSON summary with `dry_run: true`. No webhook POST.
The cursor advances even on dry-run — re-run will report `scanned: 0`
unless new audit rows have landed.

## Step 3 — Live run

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/pager.py
```

Output JSON includes `delivered`, `undelivered`, `rate_limited`. If
`undelivered > 0`, the rows are queued in `state/paging-undelivered.jsonl`
with a retry counter.

## Step 4 — Retry queued failures

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/pager.py --retry
```

Successfully retried events are dropped from the queue. Events past
`max_retries` are dropped and logged as exhausted in `state/paging-runs.log`.

## Step 5 — Periodic runner

Wire pager.py into a cron/systemd timer. Suggested cadence:

| Time window | Cadence |
|-------------|---------|
| Business hours | every 30s |
| Off-hours | every 5m |
| Retry sweep | every 15m, post `--retry` |

</runbook>

<config_reference>

| Field | Default | Meaning |
|-------|---------|---------|
| `enabled` | `false` | Master switch. False = classify only, never POST. |
| `webhook_url` | `""` | JSON-POST endpoint. |
| `min_severity` | `"HIGH"` | Floor: DEBUG < INFO < LOW < MEDIUM < HIGH < CRITICAL. |
| `rate_limit_per_min` | `5` | Token bucket. Suppressed pages do NOT enter the retry queue. |
| `timeout_seconds` | `5` | Per-POST timeout. |
| `max_retries` | `3` | Drop undelivered after this many retries. |

</config_reference>

<failure_modes>

- **F08 tool-mis-invocation**: don't shell out to curl — pager.py uses
  urllib so it ships stdlib-only. If you want curl, write a wrapper, but
  keep the canonical entry point as pager.py.
- **F10 destructive without confirmation**: pager.py never deletes
  audit.jsonl rows. The cursor is the only forward-moving state.
- **F09 parallel race**: do not run two pager.py instances concurrently.
  The cursor write is atomic but two runners will both POST the same rows.
  Cron-style serialization is sufficient — one runner per minute.

</failure_modes>

<contract>
Advisory only. Paging is observability, not a gate. Even when the webhook
is unreachable, pager.py exits 0 and writes to `state/paging-undelivered.jsonl`.
F-011 closure: HIGH+ events are routed to operator-configured paging.
Operator wires the actual endpoint; this skill ships the routing.
</contract>
