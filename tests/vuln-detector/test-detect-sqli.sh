#!/usr/bin/env bash
# Test: vuln-detector detects SQL injection via template literal
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/vuln-detector/hooks/post-tool-use/detect-vuln.sh"

# Create temp file with SQL injection vulnerability
TMPFILE=$(mktemp /tmp/reaper-test-XXXXXX.ts)
cat > "$TMPFILE" << 'VULN'
const userId = req.params.id;
const query = `SELECT * FROM users WHERE id = ${userId}`;
db.query(query);
VULN

TRANSCRIPT=$(mktemp /tmp/reaper-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "$TMPFILE" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/vuln-detector"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT"
rm -f /tmp/reaper-vuln* 2>/dev/null

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Verify: should detect CWE-89
if ! echo "$OUTPUT" | grep -q "CWE-89\|SQL\|injection\|VULN"; then
  echo "FAIL: SQL injection not detected"
  exit 1
fi

exit 0
