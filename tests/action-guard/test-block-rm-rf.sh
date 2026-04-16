#!/usr/bin/env bash
# Test: action-guard blocks rm -rf /
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/action-guard/hooks/pre-tool-use/guard-action.sh"

TRANSCRIPT=$(mktemp /tmp/reaper-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Bash" \
  --arg cmd "rm -rf /" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{command:$cmd}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/action-guard"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TRANSCRIPT"

# Verify: exit code must be 2 (BLOCKED)
if [[ $EXIT_CODE -ne 2 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 2 (BLOCKED)"
  exit 1
fi

# Verify: stderr should contain BLOCKED
if ! echo "$OUTPUT" | grep -q "BLOCKED"; then
  echo "FAIL: no BLOCKED message in output"
  exit 1
fi

exit 0
