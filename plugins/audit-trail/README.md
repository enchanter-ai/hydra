# audit-trail

Comprehensive security event logging with rotation and reporting.

## Install

Part of the [Reaper](../..) bundle — **all 5 plugins install together**. `audit-trail` only has events to log because `secret-scanner`, `vuln-detector`, `action-guard`, and `config-shield` emit them. Installing it alone gives you an empty JSONL file and a report with no findings. The manifest lists the other four as dependencies.

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install reaper-audit-trail@reaper
```

Claude Code resolves the dependency chain and installs all 5.

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
