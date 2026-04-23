#!/usr/bin/env bash
# Test: mask_secret properly masks secret values
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$HYDRA_ROOT/shared/constants.sh"
source "$HYDRA_ROOT/shared/sanitize.sh"

# Test 1: mask a long secret
MASKED=$(mask_secret "AKIAIOSFODNN7EXAMPLE")
if [[ "$MASKED" != "AKIA...MPLE" ]]; then
  echo "FAIL: expected 'AKIA...MPLE', got '$MASKED'"
  exit 1
fi

# Test 2: short values should be fully redacted
MASKED=$(mask_secret "short")
if [[ "$MASKED" != "[REDACTED]" ]]; then
  echo "FAIL: expected '[REDACTED]', got '$MASKED'"
  exit 1
fi

# Test 3: mask a GitHub token
MASKED=$(mask_secret "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij")
if [[ "$MASKED" != "ghp_...ghij" ]]; then
  echo "FAIL: expected 'ghp_...ghij', got '$MASKED'"
  exit 1
fi

exit 0
