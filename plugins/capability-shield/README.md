# capability-shield

> **OPT-IN BLOCKING.** Sibling of [`capability-fence`](../capability-fence)
> (advisory). When `state/capability-policy.json` sets `enabled: true`,
> this PreToolUse hook **blocks** (`exit 2`) any tool call whose name is
> not in the active SKILL.md frontmatter `allowed-tools` list. Default
> disabled — out of the box this shield does nothing.

## Why a separate plugin from capability-fence

`capability-fence` is **observability** (advisory, always exits 0, prints
to stderr, logs to `state/fence-log.ndjson`). It conforms to
`../foundations/packages/core/conduct/hooks.md` "Hooks inform, they don't decide". Operators
who want enforcement, not just signal, install **this** plugin in
addition to (or instead of) the fence.

Splitting them keeps:

- The advisory contract clean for users who don't want surprises.
- The blocking contract opt-in and reversible by editing one JSON file.
- The override of `hooks.md` localized to one plugin (this one), which
  CLAUDE.md explicitly permits: *"When a module conflicts with a
  plugin-local instruction, the plugin wins — but log the override."*

## hooks.md override (logged)

This plugin **overrides** the project-wide rule in
`../foundations/packages/core/conduct/hooks.md` that hooks must be advisory-only. The override
is bounded:

1. **Off by default.** Disabled `state/capability-policy.json` ships out
   of the box; `enabled:false` means the hook is a silent no-op.
2. **Fail-safe.** Any error in the shield itself (malformed policy,
   parse failure, IO error, missing python) results in `exit 0` — never
   blocks. Operator must fix the config to re-enable enforcement.
3. **Subagent-recursion guard.** `$CLAUDE_SUBAGENT` set → exit 0.
4. **Pre-filtered hot path.** Disabled-policy fast path is a single
   `grep` + early exit, no python startup.

## Opt-in flow

```bash
# 1) Copy the example policy.
cp state/capability-policy.example.json state/capability-policy.json

# 2) Edit to enable.
# {"enabled": true, "fail_on_missing_skill": false, "require_signed_skills": false}

# 3) Restart Claude Code so the hook is registered.

# 4) Reverse anytime by setting enabled:false.
```

## Signed SKILL.md (R-018, closes F-PT-14 / F-PT-15 / F-PT-46)

Out of the box the shield's allowed-tools list is read from whichever
SKILL.md the mtime-walk happens to surface. The 2026-05 pentest showed
that an attacker with write access (or a compromised earlier turn) can
self-mutate SKILL.md between trust-check and re-read — a TOCTOU primitive
against the capability trust root. The fix is a signed sidecar verified
*before* the frontmatter is parsed.

### Install-time signing

After authoring or editing each SKILL.md, run:

```bash
scripts/sign-skill.sh path/to/skills/<name>/SKILL.md
# → writes path/to/skills/<name>/SKILL.md.sig
```

Sign every SKILL.md that the shield might surface (anywhere under your
project's `skills/` tree, plus any plugin's `skills/` you've installed).
The script uses the **same HMAC key as `audit-trail`**:

1. `$HYDRA_AUDIT_HMAC_KEY` env var (preferred — operator-rotated)
2. `state/hmac-key.bin` (auto-generated 256-bit hex, mode 0600)
3. plain-SHA-256 fallback with a loud stderr warning (last resort)

### Policy opt-in

After every SKILL.md has a sidecar, flip the gate:

```jsonc
{
  "enabled": true,
  "fail_on_missing_skill": false,
  "require_signed_skills": true
}
```

With `require_signed_skills:true` the shield runs `verify-skill.sh` on
the located SKILL.md **before** parsing its frontmatter. On exit code:

- `0` → signature matches → continue to allowed-tools evaluation.
- `1` → mismatch (SKILL.md changed without re-signing) → block with advisory.
- `2` → no sidecar (.sig missing) → block with advisory.

With `require_signed_skills:false` (default) the verify step is skipped
entirely — behavior is identical to today's release. Operators who can't
yet sign all their SKILL.mds keep the legacy flow.

### Re-signing on edit

Editing a SKILL.md invalidates its sidecar. Re-run `sign-skill.sh` on the
edited file before the next tool call, or the shield will block. A wrapper
in CI / pre-commit (signs every modified `SKILL.md` before staging) is the
recommended ergonomic.

### Key rotation

Rotating the HMAC key invalidates every existing sidecar. To rotate:

```bash
# 1) Pick a new key.
export HYDRA_AUDIT_HMAC_KEY="$(openssl rand -hex 32)"
#    (or regenerate state/hmac-key.bin: rm state/hmac-key.bin and the next
#     sign-skill.sh run will create a fresh one.)

# 2) Re-sign every SKILL.md in scope.
find . -name SKILL.md -type f \
  -exec scripts/sign-skill.sh {} \;

# 3) Verify a sample to confirm the new key matches.
scripts/verify-skill.sh -v skills/<name>/SKILL.md
```

Rotation cadence: align with `audit-trail` rotation (the same key gates
the audit chain). Stale sidecars are a hard block, not a silent weakness,
so rotation churn surfaces immediately — no quiet failure modes.

## Behavior

1. **PreToolUse hook on all tools.** Pre-filter: bails if policy file
   absent OR `enabled:true` not present in the JSON.
2. **shield-check.py:**
   - Loads `state/capability-policy.json`. If disabled → exit 0.
   - Reads the hook payload from stdin (`tool_name`, `tool_input`).
   - Locates the active SKILL.md (env `CLAUDE_SKILL_PATH` first, then
     most-recently-modified `SKILL.md` in the cwd ancestor walk, same
     algorithm as `capability-fence`).
   - If no SKILL.md and `fail_on_missing_skill:false` (default) → exit 0.
     If `fail_on_missing_skill:true` → exit 2 with a stderr advisory.
   - Parses YAML frontmatter; extracts `allowed-tools` (or legacy
     `tools`). Empty/absent list → best-effort scope, exit 0.
   - Matches `tool_name` against each entry, including `Bash(prefix *)`
     glob forms. In list → exit 0. Not in list → stderr advisory + exit 2.
3. **Subagent-recursion guard** (`$CLAUDE_SUBAGENT`).
4. **Fail-safe.** Any unhandled exception → exit 0.

## Stderr block message

```
=== capability-shield (BLOCKED) ===
Skill <name> attempted to invoke <tool> which is NOT in its declared
allowed-tools list (<list>). SKILL.md: <path>. To unblock: add the tool
to the skill's allowed-tools, or set enabled:false in
state/capability-policy.json.
```

## Files

```
plugins/capability-shield/
├── .claude-plugin/plugin.json
├── README.md                           (this file)
├── hooks/hooks.json                    (PreToolUse registration)
├── hooks/pretooluse.sh                 (recursion guard, fail-safe, propagates exit 2)
├── scripts/shield-check.py             (frontmatter parse, matcher, exit 2 on block)
├── scripts/sign-skill.sh               (R-018: HMAC-sign a SKILL.md → sidecar .sig)
├── scripts/verify-skill.sh             (R-018: verify SKILL.md against its sidecar)
├── skills/shield-awareness/SKILL.md    (interpretation + opt-in flow)
└── state/capability-policy.example.json (default-disabled template)
```

## See also

- [`capability-fence`](../capability-fence) — advisory sibling
  (observability only).
- `../foundations/packages/core/conduct/hooks.md` — advisory-default rule (overridden here,
  per the override-note above).
- `wixie/../foundations/packages/core/conduct/delegation.md` — per-role tool whitelist table.
- F-010 (capability-allowlist enforcement) — closed by this plugin.
