#!/usr/bin/env bash
# Test: all new pattern files follow the required schema (id, pattern, severity, cwe, etc.)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REAPER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATTERNS_DIR="$REAPER_ROOT/shared/patterns"

NEW_FILES=(
  cicd-attacks.json container-security.json iac-misconfig.json crypto-weakness.json
  auth-bypass.json ssrf-patterns.json api-security.json ai-agent-attacks.json
  regex-dos.json deserialization.json file-operations.json logging-forgery.json
  prototype-pollution.json dependency-confusion.json header-security.json
)

for file in "${NEW_FILES[@]}"; do
  FULL="$PATTERNS_DIR/$file"
  # Every entry must have id, pattern, severity, category, description, cwe
  MISSING=$(jq -r '.[] | select(.id == null or .pattern == null or .severity == null or .category == null or .description == null or .cwe == null) | .id // "unknown"' "$FULL" 2>/dev/null)
  if [[ -n "$MISSING" ]]; then
    echo "FAIL: $file has entries missing required fields: $MISSING"
    exit 1
  fi
  # Verify severity is one of the allowed values
  BAD_SEV=$(jq -r '.[] | select(.severity != "critical" and .severity != "high" and .severity != "medium" and .severity != "low" and .severity != "info") | .id' "$FULL" 2>/dev/null)
  if [[ -n "$BAD_SEV" ]]; then
    echo "FAIL: $file has invalid severity on: $BAD_SEV"
    exit 1
  fi
done

exit 0
