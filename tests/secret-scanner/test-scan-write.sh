#!/usr/bin/env bash
# Test: secret-scanner detects AWS access key in written file
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

# Create temp file with a fake AWS key
# Use a filename WITHOUT "test" so is_test_file doesn't suppress output
TMPFILE=$(mktemp /tmp/reaper-scan-XXXXXX.py)
echo 'AWS_KEY = "AKIAIOSFODNN7EXAMPLE"' > "$TMPFILE"

# Create temp transcript for session hash
TRANSCRIPT=$(mktemp /tmp/reaper-xscript-XXXXXX)
echo "test" > "$TRANSCRIPT"

# Build mock hook input
INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "$TMPFILE" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

# Set plugin root
export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/secret-scanner"

# Run hook
OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

# Cleanup
rm -f "$TMPFILE" "$TRANSCRIPT"
rm -f /tmp/reaper-secrets-* 2>/dev/null

# Verify: exit code must be 0 (hooks never fail)
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Verify: stderr should contain [Reaper] warning
if ! echo "$OUTPUT" | grep -q "\[Reaper\]"; then
  echo "FAIL: no [Reaper] output found"
  exit 1
fi

exit 0
