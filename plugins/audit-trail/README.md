# audit-trail

Comprehensive security event logging with rotation and reporting.

## Algorithm
- **R8: Bayesian Threat Convergence** — cross-session EMA of threat rates

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

## Command
`/reaper:audit` — event timeline, severity filters, report generation

## Agent
`chronicler` (Haiku) — session security summary and posture analysis
