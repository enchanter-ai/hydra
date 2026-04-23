#!/usr/bin/env bash
# Test: sanitize_path blocks path traversal
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$HYDRA_ROOT/shared/sanitize.sh"

# Test 1: block simple path traversal
if sanitize_path "../../../etc/passwd" 2>/dev/null; then
  echo "FAIL: did not block ../../../etc/passwd"
  exit 1
fi

# Test 2: block URL-encoded path traversal
if sanitize_path "%2e%2e/%2e%2e/etc/passwd" 2>/dev/null; then
  echo "FAIL: did not block URL-encoded traversal"
  exit 1
fi

# Test 3: allow normal path
RESULT=$(sanitize_path "src/index.ts" 2>/dev/null)
if [[ -z "$RESULT" ]]; then
  echo "FAIL: blocked normal path src/index.ts"
  exit 1
fi

# Test 4: block path outside project root
if sanitize_path "/etc/passwd" "/home/user/project" 2>/dev/null; then
  echo "FAIL: did not block path outside project root"
  exit 1
fi

exit 0
