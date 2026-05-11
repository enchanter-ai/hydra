#!/usr/bin/env bash
# config-shield: PreToolUse hook on Edit / Write.
#
# Detects when the tool is about to write to a signed-config file
# (.claude/settings*.json or hooks/hooks.json) and emits an advisory
# reminder to re-sign after the write.
#
# Advisory only — never blocks. Exit 0 always.

# Subagent recursion guard — see shared/conduct/hooks.md
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

trap 'exit 0' INT TERM
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# ── Read hook input ──
HOOK_INPUT=$(head -c 1048576 2>/dev/null)
[[ -z "$HOOK_INPUT" ]] && exit 0

# Pull tool name and target path. Edit/Write both use file_path.
TOOL_NAME=$(printf "%s" "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
case "$TOOL_NAME" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

TARGET=$(printf "%s" "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
[[ -z "$TARGET" ]] && exit 0

# ── Match signed-config paths ──
case "$TARGET" in
  */.claude/settings.json|*/.claude/settings.local.json|*/hooks/hooks.json) ;;
  *) exit 0 ;;
esac

# ── Policy: only warn if enabled (default on) ──
POLICY_FILE="${PLUGIN_ROOT}/state/config-shield-policy.json"
WARN_ON_WRITE=true
if [[ -f "$POLICY_FILE" ]]; then
  VAL=$(jq -r '.warn_on_signed_config_write // true' "$POLICY_FILE" 2>/dev/null)
  [[ "$VAL" == "false" ]] && WARN_ON_WRITE=false
fi

if [[ "$WARN_ON_WRITE" == "true" ]]; then
  printf "=== config-shield (advisory) === Write detected to signed-config file %s. After save, re-sign with: bash plugins/config-shield/scripts/sign-config.sh %s\n" "$TARGET" "$TARGET" >&2
fi

exit 0
