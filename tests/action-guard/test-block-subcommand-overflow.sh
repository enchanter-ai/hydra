#!/usr/bin/env bash
# Test: action-guard blocks 50+ subcommand overflow (Adversa AI bypass)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/action-guard/hooks/pre-tool-use/guard-action.sh"

TRANSCRIPT=$(mktemp /tmp/hydra-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

# Build a command with 60 subcommands — should trigger R7 overflow detection
CMD=""
for i in $(seq 1 60); do
  CMD="${CMD}echo $i; "
done

INPUT=$(jq -cn --arg tool "Bash" --arg cmd "$CMD" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{command:$cmd}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/action-guard"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TRANSCRIPT"

[[ $EXIT_CODE -ne 2 ]] && echo "FAIL: exit code was $EXIT_CODE, expected 2 (BLOCKED for overflow)" && exit 1
echo "$OUTPUT" | grep -q "BLOCKED\|subcommand\|overflow" || { echo "FAIL: subcommand overflow not detected"; exit 1; }
exit 0
