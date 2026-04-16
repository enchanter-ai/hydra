#!/usr/bin/env bash
# Test: vuln-detector detects command injection via subprocess shell=True
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/vuln-detector/hooks/post-tool-use/detect-vuln.sh"

TMPFILE=$(mktemp /tmp/reaper-scan-XXXXXX.py)
cat > "$TMPFILE" << 'CMDI'
import subprocess
user_cmd = request.args.get('cmd')
subprocess.run(user_cmd, shell=True)
CMDI

TRANSCRIPT=$(mktemp /tmp/reaper-xscript-XXXXXX)
echo "x" > "$TRANSCRIPT"

INPUT=$(jq -cn --arg tool "Write" --arg file "$TMPFILE" --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/vuln-detector"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -f "$TMPFILE" "$TRANSCRIPT" /tmp/reaper-vuln* 2>/dev/null

[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code $EXIT_CODE" && exit 1
echo "$OUTPUT" | grep -q "CWE-78\|command injection\|shell=True" || { echo "FAIL: command injection not detected"; exit 1; }
exit 0
