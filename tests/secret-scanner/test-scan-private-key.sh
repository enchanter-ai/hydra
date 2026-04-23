#!/usr/bin/env bash
# Test: secret-scanner detects RSA private key
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/secret-scanner/hooks/post-tool-use/scan-secrets.sh"

TMPFILE=$(mktemp /tmp/hydra-scan-XXXXXX.pem)
cat > "$TMPFILE" << 'KEY'
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyF068oFcxd7fN+H6mOQ==
-----END RSA PRIVATE KEY-----
KEY

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
echo "$OUTPUT" | grep -q "\[Hydra\].*CRITICAL" || { echo "FAIL: private key not flagged CRITICAL"; exit 1; }
exit 0
