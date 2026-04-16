---
name: safety-awareness
description: >
  Use when the developer asks about blocked commands, safety checks,
  why something was blocked, or wants to adjust strictness mode.
  Auto-triggers on: "blocked", "was that safe", "why blocked",
  "action guard", "dangerous command", "safety mode", "strictness".
allowed-tools:
  - Read
  - Grep
  - Bash
---

<purpose>
Help the developer understand action-guard decisions.
Explain why commands were blocked or warned.
Guide strictness mode configuration.
</purpose>

<constraints>
1. NEVER encourage disabling safety checks without explaining the risk.
2. ALWAYS explain WHY a command was classified as dangerous.
3. ALWAYS suggest safe alternatives when blocking.
4. Log mode changes as "trust override" — never suppress future warnings.
</constraints>

<decision_tree>
IF user asks why a command was blocked:
  → Read ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl
  → grep for "action_blocked" events
  → Show: blocked command pattern, category, severity, reason
  → Suggest safe alternative

IF user wants to change strictness:
  → Read ${CLAUDE_PLUGIN_ROOT}/state/config.json (or show defaults)
  → Explain modes:
    - strict: blocks both "block" and "warn" patterns
    - balanced (default): blocks "block" patterns, warns on "warn" patterns
    - permissive: warns only, never blocks
  → To change: write {"mode": "balanced"} to state/config.json

IF user asks about safety of a specific command:
  → Classify command against dangerous-ops.json patterns
  → Report: safe / warn / block with explanation

IF user asks about subcommand overflow:
  → Explain R7: commands with 50+ subcommands bypass deny rules
  → Reference: Adversa AI attack vector discovery
</decision_tree>

<output_format>
## Action Guard Status

**Mode:** [strict/balanced/permissive]

### Recent Blocks
| Command | Category | Reason |
|---------|----------|--------|
| `rm -rf /` | filesystem | Recursive force delete from root |

### Recent Warnings
| Command | Category | Reason |
|---------|----------|--------|
| `git push --force` | git | Force push — can overwrite history |

### Safe Alternatives
- Instead of `rm -rf /`: specify exact path
- Instead of `git push --force`: use `git push --force-with-lease`
</output_format>

<escalate_to_sonnet>
IF command context is ambiguous:
  "ESCALATE_TO_SONNET: ambiguous command classification — deeper context analysis needed"
</escalate_to_sonnet>
