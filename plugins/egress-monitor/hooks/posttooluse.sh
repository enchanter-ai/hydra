#!/usr/bin/env bash
# egress-monitor: PostToolUse advisory hook on WebFetch / WebSearch / Bash.
# Logs network destinations to state/log.ndjson. Emits stderr advisory on
# first-seen domains. ADVISORY ONLY: always exit 0. Per shared/conduct/hooks.md.
#
# Budget: PostToolUse <100ms target. We pre-filter in pure bash before the
# python startup cost so the common case (non-network Bash, all other tools)
# returns in ~5ms.

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

TOOL=$(printf "%s" "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null)

# Cheap pre-filter: WebFetch and WebSearch always pass; Bash only if its
# command contains a network verb. Anything else: silent exit 0.
case "$TOOL" in
  WebFetch|WebSearch) ;;
  Bash)
    CMD=$(printf "%s" "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
    case "$CMD" in
      *curl*|*wget*|*http*|*"git push"*|*"git pull"*|*"git clone"*|*"git fetch"*) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

# Hand the full payload to the python helper via stdin.
# `|| true` ensures any python failure cannot affect this hook's exit code.
printf "%s" "$HOOK_INPUT" | "$PY" "${PLUGIN_ROOT}/scripts/egress-log.py" || true

# ALWAYS exit 0. Advisory contract — see shared/conduct/hooks.md.
exit 0
