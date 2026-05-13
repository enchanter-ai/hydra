# egress-shield

**OPT-IN BLOCKING** PreToolUse egress allowlist. Pairs with
[`hydra-egress-monitor`](../egress-monitor/) (advisory). When the
operator opts in, the shield exits 2 on any `WebFetch` / `WebSearch` /
`Bash`-network call whose destination host is not in the allowlist.

> **Default disabled.** Out of the box, this plugin installs but does
> nothing. The operator must explicitly flip `enabled: true` in
> `state/egress-policy.json` to activate enforcement.

## Why this plugin exists separately from egress-monitor

[`../foundations/packages/core/conduct/hooks.md`](../../../foundations/packages/core/conduct/hooks.md) codifies the
project rule **"Hooks inform, they don't decide."** The right pattern
for adding enforcement is *not* to promote `egress-monitor` from
advisory to blocking — that would silently break the contract every
existing operator relies on. Instead:

1. `egress-monitor` stays purely advisory. It logs every destination,
   prints first-seen advisories, **always exits 0**.
2. `egress-shield` (this plugin) is a **separate, opt-in, blocking**
   plugin. Operators who want enforcement install it AND flip the
   policy flag.

Both plugins can run side-by-side. Observability flows to
`egress-monitor`'s `state/log.ndjson`; enforcement decisions flow to
`egress-shield`'s `state/audit.ndjson` as `policy_blocked` events.

## Explicit hooks.md override

This plugin **explicitly overrides** the advisory-only contract in
`../foundations/packages/core/conduct/hooks.md`. Per `wixie/CLAUDE.md`:

> "When a module conflicts with a plugin-local instruction, the plugin
> wins — but log the override."

Override is logged here (this README), in
[`.claude-plugin/plugin.json`](.claude-plugin/plugin.json) (description
contains "OPT-IN BLOCKING"), in
[`hooks/pretooluse.sh`](hooks/pretooluse.sh) (header comment), and in
the `<override_note>` block of
[`skills/shield-awareness/SKILL.md`](skills/shield-awareness/SKILL.md).

The override is **scoped to this plugin only.** Other Hydra hooks
(including `egress-monitor`) remain advisory.

## Operator opt-in flow

```bash
# 1. Copy the example policy.
cp state/egress-policy.example.json state/egress-policy.json

# 2. Edit state/egress-policy.json:
#    - set "enabled": true
#    - replace allowlist[] with the hosts your project legitimately
#      contacts. Start narrow; expand based on policy_blocked audit
#      events.

# 3. (Optional) Tail the audit log while testing:
tail -f state/audit.ndjson
```

To **disable** the shield: set `"enabled": false` (or delete
`state/egress-policy.json`). Hook becomes a silent no-op.

## Hook contract

- **PreToolUse** matcher `WebFetch|WebSearch|Bash`.
- **Exit 2 (BLOCK)** when policy is enabled AND destination host not in
  allowlist.
- **Exit 0 (ALLOW)** in every other case.
- **Pre-filter** in pure bash so the disabled hot path is ~5ms (grep
  for `"enabled": true` — absent → exit immediately).
- **Subagent recursion guard** (`$CLAUDE_SUBAGENT`) — same template as
  the rest of Hydra.

## Failure mode: malformed policy → fail-safe (no block)

If `state/egress-policy.json` cannot be parsed, has the wrong shape,
or any unhandled exception fires inside `shield-check.py`, the shield
**defaults to allow** (exit 0). Rationale:

- A blocking shield that fails *closed* on every error becomes
  load-bearing on policy-file integrity. A typo in JSON would lock the
  operator out of every network call.
- A blocking shield that fails *open* preserves the advisory sibling's
  observability and forces the operator to fix the config to
  re-enable enforcement — the audit trail still records that
  enforcement was attempted-and-skipped, surfacing the broken state
  without holding the session hostage.

This is the same fail-open posture `../foundations/packages/core/conduct/hooks.md` § Fail-open
recommends for advisory hooks. The shield is opt-in; the cost of being
overly strict on a bad config exceeds the benefit.

## Allowlist matching

| Allowlist entry | Matches |
|---|---|
| `example.com` | `example.com` AND any subdomain (`api.example.com`, `cdn.example.com`) |
| `api.example.com` | exactly `api.example.com`; does NOT match `example.com` or other subdomains |
| `websearch` | the synthetic WebSearch destination — present → WebSearch allowed |
| `git:origin` | `git push/pull/clone/fetch origin` |
| `git:(default)` | `git push` etc. with no remote argument |

Any destination not matched by an allowlist entry is **blocked**.

## Files

```
egress-shield/
├── .claude-plugin/plugin.json
├── README.md                              (this file)
├── hooks/
│   ├── hooks.json                         (PreToolUse registration)
│   └── pretooluse.sh                      (recursion guard, fail-safe, pre-filter, exit 2 on deny)
├── scripts/shield-check.py                (policy load, host extract, allowlist match, audit emit)
├── skills/shield-awareness/SKILL.md       (interpretation + diff coaching)
└── state/
    ├── egress-policy.example.json         (template — copy to egress-policy.json to opt in)
    └── audit.ndjson                       (created on first block; locked-append target)
```

## Audit-trail event shape

```json
{"ts":"2026-05-05T12:34:56Z","event":"policy_blocked","shield":"egress-shield","tool":"WebFetch","host":"unexpected.example.com","allowlist_size":7}
```

Allow paths are not logged — `egress-monitor` (advisory) owns full
observability. This plugin's audit log records only its own
enforcement actions.

## Smoke test

```bash
# Setup: copy example to active policy, set enabled:true, allowlist [example.com]
cp state/egress-policy.example.json state/egress-policy.json
# (edit state/egress-policy.json: enabled:true, allowlist:["example.com"])

# Block path:
echo '{"tool_name":"WebFetch","tool_input":{"url":"https://blocked.example.org"}}' \
  | bash hooks/pretooluse.sh
# expected: exit 2, stderr "BLOCKED", new row in state/audit.ndjson

# Allow path:
echo '{"tool_name":"WebFetch","tool_input":{"url":"https://example.com/x"}}' \
  | bash hooks/pretooluse.sh
# expected: exit 0, no stderr

# Disabled path:
# (edit state/egress-policy.json: set enabled:false)
echo '{"tool_name":"WebFetch","tool_input":{"url":"https://anything.example.org"}}' \
  | bash hooks/pretooluse.sh
# expected: exit 0, no stderr (no-op)
```

## Closes audit finding

- **F-005** — egress allowlist blocking. The shield is opt-in but
  satisfies the closure criterion: a deployable enforcement surface
  exists; operators can flip it on per project.

## See also

- `hydra-egress-monitor` — advisory sibling; logs every destination,
  never blocks.
- `../foundations/packages/core/conduct/hooks.md` — the contract this plugin overrides.
- `wixie/CLAUDE.md` § Shared behavioral modules — override-logging
  clause that authorizes this divergence.
