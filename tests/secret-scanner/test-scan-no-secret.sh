#!/usr/bin/env bash
# Test: secret-scanner produces no findings for clean file
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

# Create temp clean file
TMPFILE=$(mktemp /tmp/hydra-test-XXXXXX.py)
echo 'print("Hello, world!")' > "$TMPFILE"

TRANSCRIPT=$(mktemp /tmp/hydra-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "$TMPFILE" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/secret-scanner"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT"
rm -f /tmp/hydra-secrets-* 2>/dev/null

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Verify: no [Hydra] output for clean file
if echo "$OUTPUT" | grep -q "\[Hydra\].*SECRET"; then
  echo "FAIL: false positive — found secret in clean file"
  exit 1
fi

exit 0
