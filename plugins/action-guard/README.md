# action-guard

Pre-execution classification and blocking of dangerous Bash commands.

## Install

Part of the [Hydra](../..) bundle. The simplest install is the `full` meta-plugin, which pulls in all 5 Hydra plugins via dependency resolution:

```
/plugin marketplace add enchanter-ai/hydra
/plugin install full@hydra
```

To install this plugin on its own: `/plugin install hydra-action-guard@hydra`. `action-guard` operates under the advisory-only hook contract from [`../enchanter-foundations/packages/core/conduct/hooks.md`](../../../enchanter-foundations/packages/core/conduct/hooks.md): when a Bash command matches a dangerous-ops pattern or trips the subcommand-overflow heuristic, the hook emits a stderr advisory (`=== action-guard (advisory) ===` block with `Would have blocked: …` + `Hint: …`) and lets the tool proceed. Block semantics belong to a deliberate Skill invocation, not a runtime gate. The advisory is only useful if `secret-scanner` catches the exfil payload on disk, `config-shield` catches the poisoned config that would mute it, `vuln-detector` catches the RCE bug upstream, and `audit-trail` records every advisory event for incident review.

## Algorithms
- **R4: Markov Action Classification** — classify commands as SAFE/WARN/BLOCK
- **R7: Subcommand Overflow Detection** — block 50+ subcommand deny-rule bypass

## Hook
- **PreToolUse** on Bash — classifies command BEFORE execution
- **Advisory only** — emits a stderr advisory block (`=== action-guard (advisory) ===` / `Would have blocked: …` / `Hint: …`) and exits 0. Never blocks tool execution. See [`../enchanter-foundations/packages/core/conduct/hooks.md`](../../../enchanter-foundations/packages/core/conduct/hooks.md).

## Strictness Modes
| Mode | Block patterns | Warn patterns |
|------|---------------|---------------|
| strict | BLOCK | BLOCK |
| balanced (default) | BLOCK | WARN |
| permissive | WARN | WARN |

## What Triggers an Advisory
- `rm -rf /`, filesystem destruction
- `DROP TABLE`, `TRUNCATE`
- `curl | bash`, reverse shells
- Force push to main/master
- Sandbox bypass attempts
- 50+ subcommand commands

Each match emits a `Would have blocked: …` stderr advisory and is recorded to `state/audit.jsonl`. Execution proceeds — the model decides what to do with the warning.

## Command
`/hydra:safety` — show mode, recent blocks, classify commands

## Agent
`guardian` (Sonnet) — evaluate ambiguous commands with full context

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
