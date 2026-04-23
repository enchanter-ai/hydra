#!/usr/bin/env bash
# Test: action-guard blocks DROP TABLE
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/action-guard/hooks/pre-tool-use/guard-action.sh"

TRANSCRIPT=$(mktemp /tmp/hydra-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Bash" --arg cmd "psql -c 'DROP TABLE users;'" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{command:$cmd}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/action-guard"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TRANSCRIPT"

[[ $EXIT_CODE -ne 2 ]] && echo "FAIL: exit code was $EXIT_CODE, expected 2 (BLOCKED)" && exit 1
echo "$OUTPUT" | grep -q "BLOCKED" || { echo "FAIL: no BLOCKED message"; exit 1; }
exit 0
