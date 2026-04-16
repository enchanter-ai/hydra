#!/usr/bin/env bash
# Test: action-guard warns on git push --force (not block in balanced mode)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/action-guard/hooks/pre-tool-use/guard-action.sh"

TRANSCRIPT=$(mktemp /tmp/reaper-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Bash" --arg cmd "git push --force origin feature-branch" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{command:$cmd}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/action-guard"
# Ensure balanced mode (default)
rm -f "$REAPER_ROOT/plugins/action-guard/state/config.json" 2>/dev/null

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TRANSCRIPT"

# In balanced mode, git push --force to non-protected branch should WARN, not BLOCK
[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code was $EXIT_CODE, expected 0 (WARN not BLOCK)" && exit 1
echo "$OUTPUT" | grep -q "\[Reaper\].*WARNING" || { echo "FAIL: no WARNING for git force push"; exit 1; }
exit 0
