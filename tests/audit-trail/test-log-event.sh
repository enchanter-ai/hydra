#!/usr/bin/env bash
# Test: audit-trail logs tool use events to audit.jsonl
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$HYDRA_ROOT/plugins/audit-trail/hooks/post-tool-use/log-event.sh"

TRANSCRIPT=$(mktemp /tmp/hydra-transcript-XXXXXX)
echo "test" > "$TRANSCRIPT"

INPUT=$(jq -cn \
  --arg tool "Write" \
  --arg file "/tmp/test.py" \
  --arg transcript "$TRANSCRIPT" \
  '{tool_name:$tool, tool_input:{file_path:$file}, transcript_path:$transcript}')

# Use the real plugin root so shared/ resolves correctly
export CLAUDE_PLUGIN_ROOT="$HYDRA_ROOT/plugins/audit-trail"

# Clean state before test
rm -f "$HYDRA_ROOT/plugins/audit-trail/state/audit.jsonl" 2>/dev/null

printf "%s" "$INPUT" | bash "$HOOK" 2>/dev/null
EXIT_CODE=$?

# Check that audit.jsonl was created
AUDIT_FILE="$HYDRA_ROOT/plugins/audit-trail/state/audit.jsonl"
HAS_ENTRY=false
if [[ -f "$AUDIT_FILE" ]] && grep -q '"event":"tool_use"' "$AUDIT_FILE" 2>/dev/null; then
  HAS_ENTRY=true
fi

# Cleanup
rm -f "$AUDIT_FILE" "$TRANSCRIPT"
rm -f "${AUDIT_FILE}.lock" 2>/dev/null
rmdir "${AUDIT_FILE}.lock" 2>/dev/null || true

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

if [[ "$HAS_ENTRY" != "true" ]]; then
  echo "FAIL: no tool_use event logged to audit.jsonl"
  exit 1
fi

exit 0
