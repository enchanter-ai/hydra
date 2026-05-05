#!/usr/bin/env bash
# package-gate: PreToolUse advisory hook on Bash commands.
# Detects npm/pip/etc. install commands and runs gate-check.py.
# ADVISORY ONLY: always exit 0, never blocks. Per shared/conduct/hooks.md.
#
# Budget: this hook gets a larger budget (~5s) than the typical PreToolUse <50ms
# because installs themselves are slow (multi-second registry pulls + dep
# resolution); the advisory check fits inside the user's existing wait without
# adding perceptible latency. Documented exception, not a precedent.

# Subagent recursion guard — see shared/conduct/hooks.md
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

# Fail-open: never propagate errors out of an advisory hook.
trap 'exit 0' ERR INT TERM
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Dependencies — silently skip if missing.
command -v jq >/dev/null 2>&1 || exit 0
PY=python3
if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY=python
  else
    exit 0
  fi
fi

# Read hook payload from stdin (capped at 256KB).
HOOK_INPUT=$(head -c 262144)
[[ -z "$HOOK_INPUT" ]] && exit 0

# Extract the actual shell command from the Bash tool input.
COMMAND=$(printf "%s" "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Cheap pre-filter: only fire on commands that look like package installs.
# Avoids the python startup cost on every Bash call.
case "$COMMAND" in
  *"npm install"*|*"npm i "*|*"pnpm add"*|*"yarn add"*) ;;
  *"pip install"*|*"uv add"*|*"uv pip install"*) ;;
  *"cargo add"*|*"go get"*|*"gem install"*|*"bundle add"*) ;;
  *) exit 0 ;;
esac

# Run the checker. Findings go to stderr (visible to Claude per hook contract).
# `|| true` ensures any python failure cannot affect this hook's exit code.
"$PY" "${PLUGIN_ROOT}/scripts/gate-check.py" "$COMMAND" || true

# ALWAYS exit 0. Advisory contract — see shared/conduct/hooks.md.
exit 0
