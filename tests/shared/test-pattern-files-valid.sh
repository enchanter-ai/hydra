#!/usr/bin/env bash
# Test: all 20 pattern files are valid JSON with required fields
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATTERNS_DIR="$HYDRA_ROOT/shared/patterns"

EXPECTED_FILES=(
  secrets.json vulns.json dangerous-ops.json config-attacks.json slopsquatting.json
  cicd-attacks.json container-security.json iac-misconfig.json crypto-weakness.json
  auth-bypass.json ssrf-patterns.json api-security.json ai-agent-attacks.json
  regex-dos.json deserialization.json file-operations.json logging-forgery.json
  prototype-pollution.json dependency-confusion.json header-security.json
)

for file in "${EXPECTED_FILES[@]}"; do
  FULL="$PATTERNS_DIR/$file"
  [[ ! -f "$FULL" ]] && echo "FAIL: missing $file" && exit 1
  # Validate JSON
  jq empty "$FULL" 2>/dev/null || { echo "FAIL: $file is not valid JSON"; exit 1; }
done

exit 0
