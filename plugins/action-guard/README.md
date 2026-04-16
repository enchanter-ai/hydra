# action-guard

Pre-execution classification and blocking of dangerous Bash commands.

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
