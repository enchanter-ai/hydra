#!/usr/bin/env bash
# Test: all pattern IDs are globally unique across all 15 new files
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATTERNS_DIR="$HYDRA_ROOT/shared/patterns"

NEW_FILES=(
  cicd-attacks.json container-security.json iac-misconfig.json crypto-weakness.json
  auth-bypass.json ssrf-patterns.json api-security.json ai-agent-attacks.json
  regex-dos.json deserialization.json file-operations.json logging-forgery.json
  prototype-pollution.json dependency-confusion.json header-security.json
)

ALL_IDS=$(mktemp /tmp/hydra-ids-XXXXXX)
for file in "${NEW_FILES[@]}"; do
  jq -r '.[].id' "$PATTERNS_DIR/$file" >> "$ALL_IDS"
done

TOTAL=$(wc -l < "$ALL_IDS")
UNIQUE=$(sort -u "$ALL_IDS" | wc -l)

rm -f "$ALL_IDS"

if [[ "$TOTAL" -ne "$UNIQUE" ]]; then
  echo "FAIL: $((TOTAL - UNIQUE)) duplicate IDs found ($TOTAL total, $UNIQUE unique)"
  exit 1
fi

exit 0
