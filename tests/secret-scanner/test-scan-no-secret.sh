#!/usr/bin/env bash
# Test: secret-scanner produces no findings for clean file
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

# Create temp clean file
TMPFILE=$(mktemp /tmp/reaper-test-XXXXXX.py)
echo 'print("Hello, world!")' > "$TMPFILE"

TRANSCRIPT=$(mktemp /tmp/reaper-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "$TMPFILE" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/secret-scanner"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT"
rm -f /tmp/reaper-secrets-* 2>/dev/null

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Verify: no [Reaper] output for clean file
if echo "$OUTPUT" | grep -q "\[Reaper\].*SECRET"; then
  echo "FAIL: false positive — found secret in clean file"
  exit 1
fi

exit 0
