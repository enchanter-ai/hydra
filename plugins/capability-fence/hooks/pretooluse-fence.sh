#!/usr/bin/env bash
# capability-fence: PreToolUse advisory hook.
# Compares the tool being invoked against the active skill's declared
# allowed-tools list (parsed from SKILL.md frontmatter). Emits a stderr
# advisory on mismatch. ALWAYS exits 0. Per shared/conduct/hooks.md.
#
# LIMITATION: this is observability, not enforcement. A tool fired from
# outside its declared lane will still execute. Real per-subagent runtime
# sandboxing requires harness/SDK changes — see README.md.
#
# Advisory contract per shared/conduct/hooks.md — never block, never exit non-zero.

# Subagent recursion guard — see shared/conduct/hooks.md
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

# Fail-open: never propagate errors out of an advisory hook.
trap 'exit 0' ERR INT TERM
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Dependencies — silently skip if missing.
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

# Pre-filter: only spend python startup if a SKILL.md is in scope.
# Two cheap signals — env var or current working tree.
if [[ -z "${CLAUDE_SKILL_PATH:-}" ]]; then
  # walk cwd up to 4 levels looking for skills/*/SKILL.md
  _found=""
  _dir="$PWD"
  for _ in 1 2 3 4; do
    if compgen -G "${_dir}/skills/*/SKILL.md" >/dev/null 2>&1 \
        || compgen -G "${_dir}/SKILL.md" >/dev/null 2>&1; then
      _found=1
      break
    fi
    _dir="$(dirname "$_dir")"
  done
  [[ -z "$_found" ]] && exit 0
fi

# Run the checker; findings → stderr (visible per hook contract).
printf "%s" "$HOOK_INPUT" | "$PY" "${PLUGIN_ROOT}/scripts/fence-check.py" \
  --plugin-root "${PLUGIN_ROOT}" || true

# ALWAYS exit 0.
exit 0
