# Reaper Architecture

> Auto-generated from codebase by `generate.py`. Run `python docs/architecture/generate.py` to regenerate.

## Interactive Explorer

Open [index.html](index.html) in a browser to explore the architecture interactively with tabbed Mermaid diagrams and plugin component cards.

## Diagrams

| Diagram | File | Description |
|---------|------|-------------|
| High Level | [highlevel.mmd](highlevel.mmd) | 5 plugins connected to Claude Code with hook phases |
| Session Lifecycle | [lifecycle.mmd](lifecycle.mmd) | SessionStart → PreToolUse → Execute → PostToolUse cycle |
| Data Flow | [dataflow.mmd](dataflow.mmd) | Data flow from tools through hooks to audit.jsonl |
| Hook Bindings | [hooks.mmd](hooks.mmd) | Hook binding map with matchers and timeouts per plugin |

## Plugin Summary

| Plugin | Hook Phase | Matcher | Timeout | Algorithms |
|--------|-----------|---------|---------|------------|
| config-shield | SessionStart | — | 30s | R5 |
| action-guard | PreToolUse | Bash | 10s | R4, R7 |
| secret-scanner | PostToolUse | Write/Edit | 15s | R1, R2 |
| vuln-detector | PostToolUse | Write/Edit | 15s | R3 |
| audit-trail | PostToolUse | All | 10s | R8 |

## Execution Order

```
1. Session Start  → config-shield scans repo configs
2. Bash call      → action-guard classifies → BLOCK or ALLOW
3. Write/Edit     → secret-scanner + vuln-detector scan content
4. Any tool       → audit-trail logs event
```
