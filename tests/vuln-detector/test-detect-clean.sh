#!/usr/bin/env bash
# Test: vuln-detector produces no findings for safe code
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/vuln-detector/hooks/post-tool-use/detect-vuln.sh"

# Create temp file with safe parameterized query
TMPFILE=$(mktemp /tmp/hydra-test-XXXXXX.py)
cat > "$TMPFILE" << 'SAFE'
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
SAFE

TRANSCRIPT=$(mktemp /tmp/hydra-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "$TMPFILE" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/vuln-detector"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT"
rm -f /tmp/hydra-vuln* 2>/dev/null

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Verify: no vulnerability warnings for safe code
if echo "$OUTPUT" | grep -q "\[Hydra\].*VULN"; then
  echo "FAIL: false positive on safe parameterized query"
  exit 1
fi

exit 0
