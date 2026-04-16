#!/usr/bin/env bash
# Test: config-shield produces no findings for clean repo
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/config-shield/hooks/session-start/scan-config.sh"

# Create temp clean project
TMPDIR=$(mktemp -d /tmp/reaper-test-project-XXXXXX)
echo '{"name": "test", "version": "1.0.0"}' > "$TMPDIR/package.json"

INPUT=$(jq -cn --arg cwd "$TMPDIR" '{cwd:$cwd}')

export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/config-shield"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -rf "$TMPDIR"

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "FAIL: exit code was $EXIT_CODE, expected 0"
  exit 1
fi

# Clean repo should not trigger config warnings
if echo "$OUTPUT" | grep -q "CRITICAL CONFIG"; then
  echo "FAIL: false positive on clean repo"
  exit 1
fi

exit 0
