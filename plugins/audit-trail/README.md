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

## Command
`/hydra:audit` — event timeline, severity filters, report generation

## Agent
`chronicler` (Haiku) — session security summary and posture analysis

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
