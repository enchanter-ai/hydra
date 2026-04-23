#!/usr/bin/env bash
# Test: vuln-detector detects pickle deserialization
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/vuln-detector/hooks/post-tool-use/detect-vuln.sh"

TMPFILE=$(mktemp /tmp/hydra-scan-XXXXXX.py)
cat > "$TMPFILE" << 'DESER'
import pickle
data = pickle.loads(user_input)
DESER

TRANSCRIPT=$(mktemp /tmp/hydra-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Write" --arg file "$TMPFILE" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/vuln-detector"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT" /tmp/hydra-vuln* 2>/dev/null

[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code $EXIT_CODE" && exit 1
echo "$OUTPUT" | grep -q "CWE-502\|pickle\|deserialization" || { echo "FAIL: pickle deserialization not detected"; exit 1; }
exit 0
