#!/usr/bin/env bash
# state-integrity: verify a defense-state file (or all watched files) against
# the baseline signatures. Returns 0 if every checked file matches.
#
# Usage:
#   verify-state.sh <path>     # verify one file against baseline.expected_sigs[path]
#   verify-state.sh --all       # verify every watched_paths entry
#
# Exit codes:
#   0  all verified
#   1  one or more mismatches (printed to stderr)
#   2  configuration/setup error (missing key, missing baseline)

set -uo pipefail

# Disable MSYS/Git-Bash POSIX→Windows path conversion (see sign-state.sh).
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${HYDRA_STATE_INTEGRITY_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
STATE_DIR="${PLUGIN_ROOT}/state"
BASELINE="${STATE_DIR}/baseline.json"
REPO_ROOT="${HYDRA_STATE_INTEGRITY_REPO_ROOT:-$(cd "${PLUGIN_ROOT}/../../.." && pwd)}"

_state_key() {
  if [[ -n "${HYDRA_STATE_INTEGRITY_HMAC_KEY:-}" ]]; then
    printf "%s" "$HYDRA_STATE_INTEGRITY_HMAC_KEY"
    return 0
  fi
  local key_file="${STATE_DIR}/hmac-key.bin"
  if [[ -r "$key_file" && -s "$key_file" ]]; then
    cat "$key_file"
    return 0
  fi
  echo "verify-state: no HMAC key available" >&2
  return 1
}

_hmac_file() {
  local path="$1"
  local key
  if ! key="$(_state_key)"; then
    return 1
  fi
  if [[ ! -f "$path" ]]; then
    printf "MISSING"
    return 0
  fi
  openssl dgst -sha256 -mac hmac -macopt "key:$key" -binary < "$path" \
    | openssl base64 -A
}

_resolve_path() {
  local p="$1"
  if [[ "$p" = /* || "$p" =~ ^[A-Za-z]: ]]; then
    printf "%s" "$p"
  else
    printf "%s/%s" "$REPO_ROOT" "$p"
  fi
}

verify_one() {
  local path="$1"
  local resolved actual expected
  resolved="$(_resolve_path "$path")"

  if ! command -v jq >/dev/null 2>&1; then
    echo "verify-state: jq required" >&2
    return 2
  fi
  if [[ ! -f "$BASELINE" ]]; then
    echo "verify-state: baseline not found: $BASELINE" >&2
    return 2
  fi

  expected=$(jq -r --arg k "$path" '.expected_sigs[$k] // empty' "$BASELINE")
  if [[ -z "$expected" ]]; then
    echo "verify-state: no expected_sig in baseline for: $path" >&2
    return 2
  fi

  actual="$(_hmac_file "$resolved")"
  if [[ "$actual" != "$expected" ]]; then
    echo "MISMATCH $path: expected=${expected:0:16}... actual=${actual:0:16}..." >&2
    return 1
  fi
  echo "OK $path"
  return 0
}

verify_all() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "verify-state: jq required" >&2
    return 2
  fi
  if [[ ! -f "$BASELINE" ]]; then
    echo "verify-state: baseline not found: $BASELINE" >&2
    return 2
  fi

  local fail=0
  local path
  while IFS= read -r path; do
    path="${path%$'\r'}"
    [[ -z "$path" ]] && continue
    verify_one "$path" || fail=1
  done < <(jq -r '.watched_paths[]' "$BASELINE")
  return $fail
}

case "${1:-}" in
  --all) verify_all ;;
  "" )
    echo "usage: verify-state.sh <path> | --all" >&2
    exit 2
    ;;
  *) verify_one "$1" ;;
esac
