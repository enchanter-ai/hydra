#!/usr/bin/env bash
# Test: secret-scanner detects GitHub Personal Access Token
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

TMPFILE=$(mktemp /tmp/hydra-scan-XXXXXX.py)
echo 'GITHUB_TOKEN = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"' > "$TMPFILE"

TRANSCRIPT=$(mktemp /tmp/hydra-xscript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Write" --arg file "$TMPFILE" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/secret-scanner"
rm -f /tmp/hydra-secrets-regex-* 2>/dev/null

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT" /tmp/hydra-secrets-* 2>/dev/null

[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code $EXIT_CODE" && exit 1
echo "$OUTPUT" | grep -q "\[Hydra\]" || { echo "FAIL: no [Hydra] for ghp_ token"; exit 1; }
exit 0
