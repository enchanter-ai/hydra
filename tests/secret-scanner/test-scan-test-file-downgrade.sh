#!/usr/bin/env bash
# Test: secrets in test files get downgraded to INFO (no stderr output)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

# File path contains "test" — should trigger INFO downgrade
TMPFILE=$(mktemp /tmp/hydra-test-fixture-XXXXXX.py)
echo 'FAKE_KEY = "AKIAIOSFODNN7EXAMPLE"' > "$TMPFILE"

TRANSCRIPT=$(mktemp /tmp/hydra-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Write" --arg file "$TMPFILE" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/secret-scanner"
rm -f /tmp/hydra-secrets-regex-* 2>/dev/null

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT" /tmp/hydra-secrets-* 2>/dev/null

[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code $EXIT_CODE" && exit 1
# Test files should NOT produce CRITICAL/HIGH output (downgraded to INFO)
if echo "$OUTPUT" | grep -q "\[Hydra\].*CRITICAL SECRET"; then
  echo "FAIL: test file should not trigger CRITICAL output"
  exit 1
fi
exit 0
