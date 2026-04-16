#!/usr/bin/env bash
# Test: secret-scanner detects Anthropic API key
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

TMPFILE=$(mktemp /tmp/reaper-scan-XXXXXX.py)
echo 'ANTHROPIC_KEY = "sk-ant-api03-aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789AbCdEfGhIjKlMnOpQrStUvWxYz01234567890AbCdEfGhIjKl"' > "$TMPFILE"

TRANSCRIPT=$(mktemp /tmp/reaper-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Write" --arg file "$TMPFILE" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/secret-scanner"
rm -f /tmp/reaper-secrets-regex-* 2>/dev/null

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT" /tmp/reaper-secrets-* 2>/dev/null

[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code $EXIT_CODE" && exit 1
echo "$OUTPUT" | grep -q "\[Reaper\].*CRITICAL" || { echo "FAIL: Anthropic key not flagged CRITICAL"; exit 1; }
exit 0
