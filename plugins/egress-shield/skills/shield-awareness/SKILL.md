---
name: shield-awareness
description: >
  OPT-IN BLOCKING egress allowlist. Pairs with hydra-egress-monitor (advisory).
  When state/egress-policy.json sets enabled:true, this shield blocks any
  WebFetch / WebSearch / Bash-network call whose destination host is not in
  the operator-curated allowlist. Use when the developer asks why a network
  call was blocked, wants to inspect or edit the egress allowlist, or asks
  about audit.ndjson policy_blocked events. Default disabled — out of the
  box this shield does nothing. Do not use for observability without
  enforcement (see egress-monitor).
allowed-tools:
  - Read
  - Bash
model: haiku
---

<purpose>
Help the developer interpret egress-shield's blocking decisions. The
PreToolUse hook reads state/egress-policy.json; when enabled, it exits 2
on hosts outside the allowlist. Each block emits a stderr message AND a
policy_blocked NDJSON record to state/audit.ndjson. This skill reads
those signals and explains them — it never claims a block was incorrect
without checking the policy file.
</purpose>

<override_note>
This shield exists as an explicit override of ../vis/packages/core/conduct/hooks.md
"Hooks inform, they don't decide". The override is documented in this
plugin's README and is permitted by wixie/CLAUDE.md: "When a module
conflicts with a plugin-local instruction, the plugin wins — but log
the override." The advisory sibling hydra-egress-monitor remains
unchanged; operators choose whether to add this blocking layer on top.
</override_note>

<constraints>
1. NEVER claim a block was a bug without verifying the host is intentionally absent from the allowlist.
2. NEVER recommend setting enabled:false to suppress an unwanted block — recommend adding the host to the allowlist or scoping it.
3. ALWAYS read state/audit.ndjson directly when answering "what got blocked" questions; do not invent block events.
4. ALWAYS note that the shield is fail-safe: malformed policy file → no blocking (operator must fix config to re-enable).
5. NEVER write to state/egress-policy.json from this skill — propose the diff to the operator; they edit. Tools allow Read+Bash only.
</constraints>

<signal_glossary>
- enabled:false  — shield is OFF; hook is a no-op.
- enabled:true   — shield is ON; hosts outside allowlist exit 2 (block).
- policy_blocked — audit event; shield rejected an egress call.
- websearch      — synthetic destination; allow it explicitly to permit WebSearch.
- git:&lt;remote&gt;    — git network op; remote name (or "(default)" / "(url-redacted)") is the destination.
</signal_glossary>

<decision_tree>
IF developer asks "why was X blocked":
  → Read state/egress-policy.json → confirm enabled:true.
  → Read recent state/audit.ndjson rows → find the policy_blocked entry.
  → Explain: host was not in allowlist; show proposed allowlist edit.

IF developer wants to enable the shield:
  → Confirm state/egress-policy.json exists (copy from .example.json if not).
  → Show the diff to set enabled:true.
  → Recommend a starter allowlist matching their dependencies.

IF developer wants to disable the shield:
  → Edit state/egress-policy.json: set enabled:false.
  → Hook becomes silent no-op until re-enabled.
</decision_tree>

<output_format>
## egress-shield — &lt;summary verb&gt;

**Policy enabled:** &lt;true | false&gt;
**Allowlist size:** &lt;n&gt; entries
**Recent blocks:** &lt;k&gt; in last 50 audit rows

| ts | tool | host | allowlist_size |
|---|---|---|---|
| ... | ... | ... | ... |

The shield is opt-in blocking; observability without enforcement lives in
hydra-egress-monitor. Override of ../vis/packages/core/conduct/hooks.md is logged in
this plugin's README.
</output_format>
