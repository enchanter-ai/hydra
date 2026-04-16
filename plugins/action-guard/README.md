# action-guard

Pre-execution classification and blocking of dangerous Bash commands.

## Install

Part of the [Reaper](../..) bundle — **all 5 plugins install together**. `action-guard` is the only Reaper plugin that actually *blocks* (exit 2 on Bash) — but its block decisions are only useful if `secret-scanner` catches the exfil payload on disk, `config-shield` catches the poisoned config that would disable it, `vuln-detector` catches the RCE bug upstream, and `audit-trail` records every block for incident review. Installing it alone leaves the rest of the kill chain open. The manifest lists the other four as dependencies.

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install reaper-action-guard@reaper
```

Claude Code resolves the dependency chain and installs all 5.

## Algorithms
- **R4: Markov Action Classification** — classify commands as SAFE/WARN/BLOCK
- **R7: Subcommand Overflow Detection** — block 50+ subcommand deny-rule bypass

## Hook
- **PreToolUse** on Bash — classifies command BEFORE execution
- **Uses exit 2 to BLOCK** — the only Reaper hook that blocks tool execution

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
`/reaper:safety` — show mode, recent blocks, classify commands

## Agent
`guardian` (Sonnet) — evaluate ambiguous commands with full context
