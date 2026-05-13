---
name: fence-awareness
description: >
  Detects subagent capability escapes by comparing the tool being invoked
  against the skill's declared allowed-tools list. Use when the developer
  asks about subagent escape, sees a tool fired from an unexpected skill,
  or audits delegation.md compliance. Auto-fires on PreToolUse. Best-effort
  observability only — does not block.
model: haiku
allowed-tools:
  - Read
  - Bash
---

<purpose>
Surface when a tool call lands outside the active skill's declared
`allowed-tools` whitelist. The PreToolUse hook prints an advisory and
appends a row to `state/fence-log.ndjson`; this skill helps the developer
read those signals and decide whether the mismatch is a genuine escape,
prompt-injection symptom, or honest mis-declaration in the SKILL.md.
</purpose>

<limitation>
Best-effort observability ONLY. The hook always exits 0; it cannot stop
a tool from executing. True per-subagent capability sandboxing needs a
harness/SDK-level permissions overlay (settings.json scoped per subagent,
or process-level confinement). That work is out of plugin scope and
tracked under finding F-050.
</limitation>

<inputs>
- Path to `state/fence-log.ndjson` (default: `${CLAUDE_PLUGIN_ROOT}/state/fence-log.ndjson`).
- Optional skill name or SKILL.md path the developer wants audited.
</inputs>

<steps>
1. Read recent fence-log entries:
   `tail -n 50 ${CLAUDE_PLUGIN_ROOT}/state/fence-log.ndjson` (jq optional).
2. For each `out-of-lane` row, locate the SKILL.md at `skill_md`.
3. Read SKILL.md frontmatter; confirm `allowed-tools` (or legacy `tools`)
   does NOT include the invoked `tool_name`.
4. Classify:
   - genuine-escape → tool unrelated to skill's job (e.g., translator
     skill firing `Bash`).
   - honest-omission → tool is plausible but missing from the whitelist;
     suggest adding it.
   - injection-symptom → tool call appears triggered by content from a
     fetched page or untrusted input; cross-check with audit-trail.
5. Recommend one of: tighten the skill's `allowed-tools`, broaden it,
   or escalate to delegation.md review.
</steps>

<output_format>
## fence-awareness — <skill_name>

**Tool fired:** <tool_name>
**Declared whitelist:** <allowed-tools>
**Classification:** <genuine-escape | honest-omission | injection-symptom>

**Recommended next step:**
- <action 1>
- <action 2>

This is observability only; the tool call was NOT blocked. Real
enforcement requires a harness-level capability overlay (F-050).
</output_format>

<constraints>
1. NEVER claim the hook blocked anything — it cannot.
2. NEVER edit SKILL.md frontmatter without showing the diff first.
3. ALWAYS cross-reference `wixie/../foundations/packages/core/conduct/delegation.md` for the
   canonical per-role tool whitelist.
4. ALWAYS note that absence of evidence in fence-log.ndjson is not
   evidence of compliance — the hook only fires when a SKILL.md is in
   scope.
</constraints>

<failure_modes>
- F01 sycophancy: agreeing the mismatch is fine without checking the
  injection-symptom path.
- F02 fabrication: inventing a SKILL.md path that does not exist on
  disk.
- F07 over-helpful substitution: editing the skill's whitelist when the
  developer only asked for an interpretation.
</failure_modes>
