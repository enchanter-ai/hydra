#!/usr/bin/env bash
# Hydra test runner — runs all test scripts, reports pass/fail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0
ERRORS=()

run_test() {
  local test_file="$1"
  local test_name
  test_name=$(basename "$test_file" .sh)
  local dir_name
  dir_name=$(basename "$(dirname "$test_file")")

  printf "  %-20s %-35s " "$dir_name" "$test_name"

  local output
  output=$(bash "$test_file" 2>&1)
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    printf "[PASS]\n"
    PASS=$((PASS + 1))
  else
    printf "[FAIL]\n"
    FAIL=$((FAIL + 1))
    ERRORS+=("$dir_name/$test_name: $output")
  fi
}

echo "══════════════════════════════════════"
echo " HYDRA TEST SUITE"
echo "══════════════════════════════════════"
echo ""

# Run tests by plugin
for plugin_dir in "$SCRIPT_DIR"/*/; do
  plugin_name=$(basename "$plugin_dir")
  if [[ "$plugin_name" == "fixtures" ]]; then continue; fi

  for test_file in "$plugin_dir"/test-*.sh; do
    [[ -f "$test_file" ]] || continue
    run_test "$test_file"
  done
done

echo ""
echo "──────────────────────────────────────"
echo " Results: $PASS passed, $FAIL failed"
echo "──────────────────────────────────────"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo ""
  echo " Failures:"
  for err in "${ERRORS[@]}"; do
    echo "   ✗ $err"
  done
fi

echo ""

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0
