# action-guard

Pre-execution classification and blocking of dangerous Bash commands.

## Install

Part of the [Hydra](../..) bundle. The simplest install is the `full` meta-plugin, which pulls in all 5 Hydra plugins via dependency resolution:

```
/plugin marketplace add enchanted-plugins/hydra
/plugin install full@hydra
```

To install this plugin on its own: `/plugin install hydra-action-guard@hydra`. `action-guard` is the only Hydra plugin that actually *blocks* (exit 2 on Bash) — but its block decisions are only useful if `secret-scanner` catches the exfil payload on disk, `config-shield` catches the poisoned config that would disable it, `vuln-detector` catches the RCE bug upstream, and `audit-trail` records every block for incident review. On its own, the rest of the kill chain stays open.

## Algorithms
- **R4: Markov Action Classification** — classify commands as SAFE/WARN/BLOCK
- **R7: Subcommand Overflow Detection** — block 50+ subcommand deny-rule bypass

## Hook
- **PreToolUse** on Bash — classifies command BEFORE execution
- **Uses exit 2 to BLOCK** — the only Hydra hook that blocks tool execution

## Strictness Modes
| Mode | Block patterns | Warn patterns |
|------|---------------|---------------|
| strict | BLOCK | BLOCK |
| balanced (default) | BLOCK | WARN |
| permissive | WARN | WARN |

## What Gets Blocked
- `rm -rf /`, filesystem destruction
- `DROP TABLE`, `TRUNCATE`
- `curl | bash`, reverse shells
- Force push to main/master
- Sandbox bypass attempts
- 50+ subcommand commands

## Command
`/hydra:safety` — show mode, recent blocks, classify commands

## Agent
`guardian` (Sonnet) — evaluate ambiguous commands with full context

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
