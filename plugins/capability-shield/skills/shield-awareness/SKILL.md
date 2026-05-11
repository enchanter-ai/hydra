---
name: capability-shield-awareness
description: >
  OPT-IN BLOCKING capability allowlist. Pairs with hydra-capability-fence
  (advisory). When state/capability-policy.json sets enabled:true, this
  shield blocks any tool call whose name is not in the active SKILL.md
  frontmatter allowed-tools list. Use when the developer asks why a tool
  call was blocked, wants to enable or tune the capability allowlist, or
  reviews a stderr "capability-shield (BLOCKED)" message. Default disabled
  — out of the box this shield does nothing. Do not use for observability
  without enforcement (see capability-fence).
allowed-tools:
  - Read
  - Bash
model: haiku
---

<purpose>
Help the developer interpret capability-shield's blocking decisions. The
PreToolUse hook reads state/capability-policy.json; when enabled, it
locates the active SKILL.md, parses its allowed-tools frontmatter, and
exits 2 on tools outside that list. Each block emits a stderr message
naming the violating tool, the skill, and the declared list. This skill
reads those signals and explains them — it never claims a block was
incorrect without checking the SKILL.md and the policy file.
</purpose>

<override_note>
This shield exists as an explicit override of ../enchanter-foundations/packages/core/conduct/hooks.md
"Hooks inform, they don't decide". The override is documented in this
plugin's README and is permitted by wixie/CLAUDE.md: "When a module
conflicts with a plugin-local instruction, the plugin wins — but log
the override." The advisory sibling hydra-capability-fence remains
unchanged; operators choose whether to add this blocking layer on top.
</override_note>

<constraints>
1. NEVER claim a block was a bug without verifying the tool is genuinely
   absent from the active SKILL.md allowed-tools list.
2. NEVER recommend setting enabled:false to suppress an unwanted block —
   recommend adding the tool to the skill's allowed-tools (in the SKILL.md
   itself) or scoping it via Bash(prefix *).
3. ALWAYS read both state/capability-policy.json AND the cited SKILL.md
   before answering "why was X blocked".
4. ALWAYS note that the shield is fail-safe: malformed policy file, missing
   skill (when fail_on_missing_skill:false), or runtime errors → no
   blocking.
5. NEVER write to state/capability-policy.json from this skill — propose
   the diff to the operator; they edit. Tools allow Read+Bash only.
</constraints>

<signal_glossary>
- enabled:false                  — shield is OFF; hook is a no-op.
- enabled:true                   — shield is ON; out-of-list tools exit 2.
- fail_on_missing_skill:false    — best-effort scope; no skill found → allow.
- fail_on_missing_skill:true     — strict; no skill found → block.
- BLOCKED stderr header          — the hook just returned exit 2.
</signal_glossary>

<decision_tree>
IF developer asks "why was X blocked":
  → Read state/capability-policy.json → confirm enabled:true.
  → Read the SKILL.md path printed in the stderr advisory.
  → Confirm the tool is genuinely absent from allowed-tools.
  → Recommend: add the tool to SKILL.md frontmatter, or set enabled:false
    if the policy is too strict for this workflow.

IF developer wants to enable the shield:
  → Confirm state/capability-policy.json exists (copy from .example.json).
  → Show the diff to set enabled:true.
  → Recommend running with fail_on_missing_skill:false initially and
    tightening once the skill-discovery path is reliable.

IF developer wants to disable the shield:
  → Edit state/capability-policy.json: set enabled:false.
  → Hook becomes silent no-op until re-enabled.
</decision_tree>

<output_format>
## capability-shield — &lt;summary verb&gt;

**Policy enabled:** &lt;true | false&gt;
**Active SKILL.md:** &lt;path or "none in scope"&gt;
**Declared allowed-tools:** &lt;list&gt;
**Blocked tool:** &lt;tool_name&gt;

The shield is opt-in blocking; observability without enforcement lives in
hydra-capability-fence. Override of ../enchanter-foundations/packages/core/conduct/hooks.md is logged in
this plugin's README.
</output_format>
