#!/usr/bin/env bash
# Test: each pattern file meets its minimum pattern count
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATTERNS_DIR="$HYDRA_ROOT/shared/patterns"

check_min() {
  local file="$1" min="$2"
  local count
  count=$(jq 'length' "$PATTERNS_DIR/$file")
  if [[ "$count" -lt "$min" ]]; then
    echo "FAIL: $file has $count patterns, minimum is $min"
    exit 1
  fi
}

# Original files
check_min "secrets.json" 300
check_min "vulns.json" 150
check_min "dangerous-ops.json" 100
check_min "config-attacks.json" 110

# New files
check_min "cicd-attacks.json" 120
check_min "container-security.json" 100
check_min "iac-misconfig.json" 120
check_min "crypto-weakness.json" 80
check_min "auth-bypass.json" 80
check_min "ssrf-patterns.json" 60
check_min "api-security.json" 80
check_min "ai-agent-attacks.json" 100
check_min "regex-dos.json" 40
check_min "deserialization.json" 60
check_min "file-operations.json" 50
check_min "logging-forgery.json" 40
check_min "prototype-pollution.json" 35
check_min "dependency-confusion.json" 50
check_min "header-security.json" 50

# Grand total: existing + new >= 2000
TOTAL=0
for f in "$PATTERNS_DIR"/*.json; do
  base=$(basename "$f")
  # slopsquatting uses a different format
  if [[ "$base" == "slopsquatting.json" ]]; then
    continue
  fi
  COUNT=$(jq 'if type == "array" then length else 0 end' "$f" 2>/dev/null || echo 0)
  TOTAL=$((TOTAL + COUNT))
done
# Add slopsquatting (~199)
SLOP=$(jq '[.ecosystems | to_entries[] | .value | (.hallucinated // [] | length) + (.typosquats // [] | length)] | add' "$PATTERNS_DIR/slopsquatting.json" 2>/dev/null || echo 0)
TOTAL=$((TOTAL + SLOP))

if [[ "$TOTAL" -lt 2000 ]]; then
  echo "FAIL: total pattern count $TOTAL < 2000 minimum"
  exit 1
fi

exit 0
