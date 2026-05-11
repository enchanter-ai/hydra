#!/usr/bin/env bash
# state-integrity: sign a single defense-state file or every watched path.
#
# Usage:
#   sign-state.sh <path>          # sign one file (writes <path>.sig sidecar)
#   sign-state.sh --all            # sign every path in state/baseline.json,
#                                  # update baseline.expected_sigs in place.
#   sign-state.sh --print <path>   # print HMAC to stdout, don't write sidecar.
#
# Key resolution (mirrors audit-trail/chain-helpers.sh):
#   1. $HYDRA_STATE_INTEGRITY_HMAC_KEY env var (preferred, operator-rotated)
#   2. state/hmac-key.bin (auto-generated 256-bit, mode 0600)
#   3. fall through with a LOUD WARNING; refuse to sign (returns 1).
#
# Sidecar format: <path>.sig — single line, base64(hmac_sha256(key, file_bytes)).

set -uo pipefail

# Disable MSYS/Git-Bash automatic POSIX→Windows path conversion. Without
# this, signatures starting with "/" (a valid base64 byte) get rewritten
# to "C:/Program Files/Git/..." when passed to native jq/openssl on Windows.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL="*"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="${HYDRA_STATE_INTEGRITY_PLUGIN_ROOT:-$(cd "${SCRIPT_DIR}/.." && pwd)}"
STATE_DIR="${PLUGIN_ROOT}/state"
BASELINE="${STATE_DIR}/baseline.json"

# REPO_ROOT: the directory containing hydra/, pech/, etc. Override via env
# for tests. Default = three levels up from PLUGIN_ROOT
# (PLUGIN_ROOT = .../<repo-root>/hydra/plugins/state-integrity).
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

  if mkdir -p "$STATE_DIR" 2>/dev/null && \
     openssl rand -hex 32 > "$key_file" 2>/dev/null && \
     chmod 0600 "$key_file" 2>/dev/null; then
    cat "$key_file"
    return 0
  fi

  echo "sign-state: WARNING — no HMAC key (env unset, ${key_file} uncreatable). Refusing to sign." >&2
  return 1
}

_hmac_file() {
  local path="$1"
  local key
  if ! key="$(_state_key)"; then
    return 1
  fi
  if [[ ! -f "$path" ]]; then
    # Missing files get a stable sentinel sig so verify can detect deletion.
    printf "MISSING"
    return 0
  fi
  openssl dgst -sha256 -mac hmac -macopt "key:$key" -binary < "$path" \
    | openssl base64 -A
}

_resolve_path() {
  # Watched paths are repo-relative. Resolve against REPO_ROOT.
  local p="$1"
  if [[ "$p" = /* || "$p" =~ ^[A-Za-z]: ]]; then
    printf "%s" "$p"
  else
    printf "%s/%s" "$REPO_ROOT" "$p"
  fi
}

cmd_sign_one() {
  local path="$1"
  local resolved
  resolved="$(_resolve_path "$path")"
  local sig
  if ! sig="$(_hmac_file "$resolved")"; then
    return 1
  fi
  printf "%s\n" "$sig" > "${resolved}.sig"
  echo "signed: $path → ${sig:0:16}..."
}

cmd_print() {
  local path="$1"
  local resolved
  resolved="$(_resolve_path "$path")"
  _hmac_file "$resolved"
  printf "\n"
}

cmd_sign_all() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "sign-state: jq required for --all" >&2
    return 1
  fi
  if [[ ! -f "$BASELINE" ]]; then
    echo "sign-state: baseline not found: $BASELINE" >&2
    return 1
  fi

  local tmp
  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" EXIT

  # Build a fresh expected_sigs object.
  local sigs_json="{}"
  local path resolved sig
  while IFS= read -r path; do
    # Strip trailing CR (CRLF-tolerant on Windows checkouts).
    path="${path%$'\r'}"
    [[ -z "$path" ]] && continue
    resolved="$(_resolve_path "$path")"
    if ! sig="$(_hmac_file "$resolved")"; then
      echo "sign-state: failed to sign $path" >&2
      continue
    fi
    # Write sidecar too, when file exists.
    if [[ -f "$resolved" ]]; then
      printf "%s\n" "$sig" > "${resolved}.sig"
    fi
    sigs_json="$(printf "%s" "$sigs_json" | jq --arg k "$path" --arg v "$sig" '. + {($k): $v}')"
    echo "signed: $path → ${sig:0:16}..."
  done < <(jq -r '.watched_paths[]' "$BASELINE")

  jq --argjson sigs "$sigs_json" '.expected_sigs = $sigs' "$BASELINE" > "$tmp"
  mv "$tmp" "$BASELINE"
  trap - EXIT
  echo "baseline updated: $BASELINE"
}

main() {
  case "${1:-}" in
    --all)
      cmd_sign_all
      ;;
    --print)
      [[ -z "${2:-}" ]] && { echo "usage: sign-state.sh --print <path>" >&2; exit 1; }
      cmd_print "$2"
      ;;
    "" )
      echo "usage: sign-state.sh <path> | --all | --print <path>" >&2
      exit 1
      ;;
    *)
      cmd_sign_one "$1"
      ;;
  esac
}

main "$@"
