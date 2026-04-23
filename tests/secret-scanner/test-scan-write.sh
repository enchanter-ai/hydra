#!/usr/bin/env bash
# Test: secret-scanner detects AWS access key in written file
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

# Create temp file with a fake AWS key
# Use a filename WITHOUT "test" so is_test_file doesn't suppress output
TMPFILE=$(mktemp /tmp/hydra-scan-XXXXXX.py)
echo 'AWS_KEY = "AKIAIOSFODNN7EXAMPLE"' > "$TMPFILE"

# Create temp transcript for session hash
TRANSCRIPT=$(mktemp /tmp/hydra-xscript-XXXXXX)
echo "test" > "$TRANSCRIPT"

# Build mock hook input
INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "$TMPFILE" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

# Set plugin root
export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/secret-scanner"

# Run hook
OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

# Cleanup
rm -f "$TMPFILE" "$TRANSCRIPT"
rm -f /tmp/hydra-secrets-* 2>/dev/null

# Verify: exit code must be 0 (hooks never fail)
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Verify: stderr should contain [Hydra] warning
if ! echo "$OUTPUT" | grep -q "\[Hydra\]"; then
  echo "FAIL: no [Hydra] output found"
  exit 1
fi

exit 0
