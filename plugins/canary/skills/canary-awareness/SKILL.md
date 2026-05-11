---
name: canary-awareness
description: >
  Seeds per-session canary tokens into WebFetch advisories and scans every
  subsequent tool input/output for the canary's appearance. Use when the
  developer wants prompt-injection detection telemetry, or asks "is my
  session compromised?". Auto-fires on PreToolUse(WebFetch) and
  PostToolUse(*). Do not use for in-prompt sanitization (see
  deep-research's <untrusted_source> wrapping).
model: haiku
allowed-tools:
  - Read
  - Bash
---

<purpose>
Translate canary-harness output into a clear assessment of whether the
current session shows evidence of indirect prompt injection. The
PreToolUse(WebFetch) hook seeds a per-session token; the PostToolUse(*)
scanner emits an advisory whenever that token appears in a subsequent
tool's input or output. This skill explains a hit and recommends next
steps.
</purpose>

<constraints>
1. NEVER claim injection succeeded based on absence of hits — absence
   only means no canary leaked, not that the session is safe.
2. NEVER block any tool call; canary is advisory by design (per
   ../enchanter-foundations/packages/core/conduct/hooks.md).
3. NEVER fabricate hit data — read state/hits.ndjson literally.
4. ALWAYS show token, tool, where (input or output), timestamp.
5. ALWAYS recommend rotation after a confirmed hit.
</constraints>

<inputs>
- state/active-canaries.json — per-session tokens currently armed.
- state/hits.ndjson — append-only log of canary leaks (one JSON per line).
</inputs>

<steps>
1. **Read state/active-canaries.json.** If empty or no sessions, report
   "no canary armed; PreToolUse(WebFetch) has not fired this session"
   and stop.
2. **Read state/hits.ndjson** if it exists. Each line is one finding:
   `{ts, token, tool, where, session_id}`.
3. **Filter hits** to the current session_id when known; otherwise
   show all.
4. **If zero hits:** report "canary armed, no leakage observed". Note
   absence is not proof of safety.
5. **If one or more hits:** for each, show token, tool, where, ts.
   Recommend: review the WebFetch source that seeded the canary, treat
   any subsequent agent action as untrusted, rotate the canary by
   clearing the session's entry from active-canaries.json.
6. **Manual rotation:** instruct the developer to delete the session
   entry from state/active-canaries.json — next WebFetch reseeds.
</steps>

<output_format>
## canary status — session <session_id or "default">

**Armed token:** <CANARY-XXXXXXXX>
**Hits this session:** <N>

(per hit:)
- **Token:** <CANARY-XXXXXXXX>
- **Tool:** <tool_name>
- **Where:** <input | output>
- **At:** <unix ts>

**Recommendation:** <next step per the constraints above>

This is advisory; no tool call was blocked.
</output_format>
