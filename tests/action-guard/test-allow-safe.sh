#!/usr/bin/env bash
# Test: action-guard allows safe commands (ls -la)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/action-guard/hooks/pre-tool-use/guard-action.sh"

TRANSCRIPT=$(mktemp /tmp/reaper-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Bash" \
  --arg cmd "ls -la" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{command:$cmd}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/action-guard"

printf "%s" "$INPUT" | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?

rm -f "$TRANSCRIPT"

# Verify: exit code must be 0 (ALLOWED)
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0 (ALLOWED)"
  exit 1
fi

exit 0
