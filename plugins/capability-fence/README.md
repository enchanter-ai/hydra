# capability-fence

> **SDK / harness coordination required.** This plugin is **best-effort
> observability only**. It cannot stop a tool from running. Real
> per-subagent runtime sandboxing — the actual fix for F-010 / F-050 —
> requires harness or SDK changes outside plugin scope: a per-subagent
> `settings.json` `permissions` overlay enforced before tool dispatch,
> or OS-level confinement (AppArmor / seccomp / per-function IAM-style
> capability boundaries). Until that lands, this hook surfaces the
> mismatch but cannot prevent it.

A PreToolUse advisory hook that reads the currently-invoked skill's
SKILL.md frontmatter `allowed-tools` (or legacy `tools`) list, compares
it against the actual tool being invoked, and emits a stderr advisory
when the tool is not in the declared whitelist.

Findings are also appended to `state/fence-log.ndjson` via cross-platform
locked append (per `wixie/prompts/ecosystem-audit/specs/templates.md`
spec G), so post-hoc review and trend analysis are possible.

## Why

`wixie/shared/conduct/delegation.md` codifies a per-role tool whitelist
("Format translator: Read, Write (target only)"; "Red-team: Read, Grep,
Glob — never Write or Edit"). Today these whitelists live as prose in
SKILL.md frontmatter — the runtime does not enforce them. Prompt
injection of a subagent's input can re-authorize tools the role was
supposed to be barred from. CWE-269 (Improper Privilege Management).

This plugin closes the **observability** half of that gap. It does not
close the **enforcement** half — only the harness can.

## Install

Part of the [Hydra](../..) bundle.

```
/plugin marketplace add enchanter-ai/hydra
/plugin install hydra-capability-fence@hydra
```

## Behavior

1. **PreToolUse hook on all tools.** Cheap pre-filter: only invokes the
   python checker when a SKILL.md is in scope (env var `CLAUDE_SKILL_PATH`
   or any ancestor `skills/*/SKILL.md` in the cwd walk).
2. **fence-check.py:**
   - Locates the active skill's SKILL.md (env var first, then most-recently
     modified `SKILL.md` in the ancestor walk).
   - Parses YAML frontmatter; extracts `allowed-tools` or `tools`.
   - Matches the tool name from the hook payload against each declared
     entry, including `Bash(prefix *)` glob forms.
   - On mismatch, prints to stderr:
     ```
     === capability-fence (advisory) ===
     Skill <name> is invoking <tool> which is NOT in its declared allowed-tools list (<list>). Possible subagent escape. Review delegation.md.
     ```
   - Appends a row to `state/fence-log.ndjson` via locked append.
3. **Always exits 0.** Per `wixie/shared/conduct/hooks.md`, advisory
   hooks never block.
4. **Subagent recursion guard** (`$CLAUDE_SUBAGENT`) — same template as
   `package-gate`.

## What it CAN do (observability)

- Surface tool calls that escape the declared whitelist, in real time on
  stderr where Claude can read them.
- Append a structured event log for post-hoc audit (`fence-log.ndjson`).
- Catch honest mis-declaration (skill author forgot to add a tool) and
  prompt-injection symptoms (subagent fired Write after ingesting a
  hostile page) using the same signal — interpretation lives in the
  `fence-awareness` skill.

## What it CANNOT do (enforcement)

- Block a tool call. The hook is contractually advisory.
- Run inside a subagent that does not inherit the parent's working
  directory or that runs without SKILL.md context.
- Catch tool calls fired from skills whose `allowed-tools` list is empty
  or absent — there is nothing to compare against.
- Replace a real per-subagent permissions overlay. That fix lives in the
  Claude Code harness; this plugin is a stop-gap.

## SDK-coordination need (the real fix)

For genuine enforcement, the harness must:

1. Read the active subagent's frontmatter `allowed-tools` at dispatch.
2. Scope the runtime tool dispatcher to only those tools for the
   duration of the subagent's turn.
3. Reject (not advise) on out-of-lane calls, regardless of prompt
   content.
4. Optionally back the scope with OS-level confinement so a compromised
   subagent process cannot escalate via shell tricks.

Until the harness ships that, capability-fence gives operators the
signal they need to detect drift.

## Files

```
plugins/capability-fence/
├── .claude-plugin/plugin.json
├── README.md                         (this file)
├── hooks/hooks.json                  (PreToolUse registration)
├── hooks/pretooluse-fence.sh         (recursion guard, fail-open, cwd pre-filter)
├── scripts/fence-check.py            (frontmatter parse, matcher, locked append)
├── skills/fence-awareness/SKILL.md   (interpretation + classification)
└── state/fence-log.ndjson.gitkeep    (locked-append target)
```

## See also

- `wixie/shared/conduct/hooks.md` — advisory contract (no exit-2).
- `wixie/shared/conduct/delegation.md` — per-role tool whitelist table.
- `wixie/prompts/ecosystem-audit/results/opus-4-7.json` — F-010, F-050.
- `wixie/prompts/ecosystem-audit/specs/templates.md` § G — locked
  JSONL append helper.
