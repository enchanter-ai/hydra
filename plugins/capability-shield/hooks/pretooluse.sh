#!/usr/bin/env bash
# capability-shield: OPT-IN BLOCKING PreToolUse hook.
# When state/capability-policy.json has enabled:true, exits 2 (block) if the
# invoked tool is not in the active SKILL.md frontmatter allowed-tools list.
# Default disabled (no-op).
#
# Override of shared/conduct/hooks.md "Hooks inform, they don't decide" —
# documented in README.md per wixie/CLAUDE.md "When a module conflicts with
# a plugin-local instruction, the plugin wins — but log the override."
#
# Pre-filter strategy: cheap bash check on policy file presence + enabled
# flag before paying python startup cost. Disabled-policy hot path ~5ms.

# Subagent recursion guard — see shared/conduct/hooks.md.
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

# Fail-safe: any error in the SHIELD itself defaults to NOT blocking.
# Per README "fail-safe", malformed config or runtime errors do not block —
# operator must fix the config to re-enable enforcement.
trap 'exit 0' ERR INT TERM
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
POLICY_FILE="${PLUGIN_ROOT}/state/capability-policy.json"

# Cheap pre-filter 1: no policy file at all → silent no-op.
[[ -f "$POLICY_FILE" ]] || exit 0

# Cheap pre-filter 2: grep for enabled:true. If absent, silent no-op.
# Avoids reading stdin or invoking python when shield is off.
if ! grep -E '"enabled"[[:space:]]*:[[:space:]]*true' "$POLICY_FILE" >/dev/null 2>&1; then
  exit 0
fi

# Dependencies — silently fail-safe if missing.
PY=python3
if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY=python
  else
    exit 0
  fi
fi

# Read hook payload (cap at 256KB).
HOOK_INPUT=$(head -c 262144)
[[ -z "$HOOK_INPUT" ]] && exit 0

# Run the shield checker. Capture exit code so we can propagate exit 2.
# Note: do NOT use `|| true` here — we WANT the exit code.
SHIELD_EXIT=0
printf "%s" "$HOOK_INPUT" | "$PY" "${PLUGIN_ROOT}/scripts/shield-check.py" \
  --plugin-root "${PLUGIN_ROOT}" || SHIELD_EXIT=$?

# Exit 2 (block) when shield says deny; anything else → exit 0 (allow).
if [[ "$SHIELD_EXIT" -eq 2 ]]; then
  exit 2
fi
exit 0
