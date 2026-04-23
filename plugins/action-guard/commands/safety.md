---
name: hydra:safety
description: >
  Show safety configuration, recent blocks and warnings,
  and classify any command for safety.
---

When the user runs `/hydra:safety`, show the current safety status.

## Data Source

- Read `${CLAUDE_PLUGIN_ROOT}/state/config.json` for current mode (default: balanced).
- Read `${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl` and filter for `"event":"action_blocked"` and `"event":"action_warned"` entries.

## Output Format

```
## Hydra Action Guard

**Mode:** balanced (block dangerous, warn risky)
**Available modes:** strict | balanced | permissive

### Recent Blocks ([N])
| Time | Command | Category | Reason |
|------|---------|----------|--------|
| 14:23 | rm -rf / | filesystem | Recursive delete from root |

### Recent Warnings ([N])
| Time | Command | Category | Reason |
|------|---------|----------|--------|
| 14:25 | git push --force | git | Force push overwrites history |

### How to Change Mode
Write to state/config.json:
- Strict: {"mode": "strict"} — blocks both "block" and "warn" patterns
- Balanced: {"mode": "balanced"} — blocks dangerous, warns risky
- Permissive: {"mode": "permissive"} — warns only, never blocks
```

## Rules

1. Show current mode prominently.
2. List recent blocks before warnings.
3. Suggest safe alternatives for each blocked command.
4. Show "No blocked or warned actions" if audit is clean.
