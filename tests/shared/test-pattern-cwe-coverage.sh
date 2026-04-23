#!/usr/bin/env bash
# Test: pattern files collectively cover at least 50 unique CWEs
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

CWE_FILE=$(mktemp /tmp/hydra-cwe-XXXXXX)
for file in "${NEW_FILES[@]}"; do
  jq -r '.[].cwe // empty' "$PATTERNS_DIR/$file" >> "$CWE_FILE"
done

UNIQUE_CWES=$(sort -u "$CWE_FILE" | grep -c "CWE-")
rm -f "$CWE_FILE"

if [[ "$UNIQUE_CWES" -lt 50 ]]; then
  echo "FAIL: only $UNIQUE_CWES unique CWEs, minimum 50"
  exit 1
fi

exit 0
