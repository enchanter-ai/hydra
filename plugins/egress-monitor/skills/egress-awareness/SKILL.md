---
name: egress-awareness
description: >
  Logs every WebFetch / WebSearch / Bash-network destination to an append-only
  NDJSON and surfaces first-seen domains as advisory warnings. Use when the
  developer asks "what did this session reach out to?" or "show me egress",
  wants a per-session list of contacted hosts, asks about an
  egress-monitor advisory, or wants to inspect state/log.ndjson. Auto-fires on
  PostToolUse for network tools. Do not use for in-process state inspection
  (see audit-trail).
allowed-tools:
  - Read
  - Bash
---

<purpose>
Help the developer interpret egress-monitor's append-only network log and
its first-seen-domain advisories. The hook records one NDJSON record per
network tool call to state/log.ndjson; this skill summarises that log and
explains advisory output.
</purpose>

<constraints>
1. NEVER claim a destination is malicious — first-seen is a recency signal,
   not a verdict.
2. NEVER block, retry, or re-issue a network call; egress-monitor is purely
   observational (per ../vis/packages/core/conduct/hooks.md).
3. NEVER log query content for WebSearch — only length is recorded.
4. NEVER expose git remote URLs — git network ops log only the remote name.
5. ALWAYS read state/log.ndjson directly when answering session-egress
   questions; do not invent destinations.
</constraints>

<signal_glossary>
- first_seen=true   — host has not appeared in seen-domains.json before;
  emitted as a stderr advisory once per host per repo state.
- websearch         — synthetic destination written for every WebSearch
  call; query content is intentionally not logged.
- git:&lt;remote&gt;       — git network op; the remote name (or "(default)" /
  "(url-redacted)") is logged, never the URL.
</signal_glossary>

<decision_tree>
IF developer asks "what did this session reach out to":
  → Read state/log.ndjson.
  → Group by host, count occurrences, list earliest + latest ts per host.
  → Distinguish first_seen=true rows.

IF developer asks about a specific egress-monitor advisory:
  → Identify the host from the advisory block in context.
  → Grep state/log.ndjson for that host; report tool, ts, count.
  → Recommend: confirm the host matches an expected dependency.

IF developer wants to "reset" first-seen state:
  → Edit state/seen-domains.json directly (it is plain JSON: {"hosts": [...]}).
  → New runs will re-emit advisories until each host is re-added.
</decision_tree>

<output_format>
## egress-monitor — &lt;summary verb&gt;

**Hosts contacted:** &lt;n&gt; (&lt;k&gt; first-seen)

| Host | Tool | Count | First | Last |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

This is observational; no calls were blocked.
</output_format>
