#!/usr/bin/env bash
# config-shield: verify a single config file's HMAC-SHA-256 signature.
#
# Recomputes the signature using the same canonicalisation + key as
# sign-config.sh and compares against the sidecar <config-file>.sig.
#
# Exit codes:
#   0 — signature present and matches
#   1 — signature present but MISMATCH (tampering suspected)
#   2 — signature file missing (config unsigned)
#
# Usage: bash verify-config.sh <config-file>

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <config-file>" >&2
  exit 1
fi

CONFIG_FILE="$1"
SIG_FILE="${CONFIG_FILE}.sig"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "verify-config: file not found: $CONFIG_FILE" >&2
  exit 1
fi

if [[ ! -f "$SIG_FILE" ]]; then
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../state"

# ── Key resolution (read-only — never auto-create on verify path) ──
_signing_key() {
  if [[ -n "${HYDRA_AUDIT_HMAC_KEY:-}" ]]; then
    printf "%s" "$HYDRA_AUDIT_HMAC_KEY"
    return 0
  fi

  local key_file="$STATE_DIR/hmac-key.bin"

  if [[ -r "$key_file" && -s "$key_file" ]]; then
    cat "$key_file"
    return 0
  fi

  echo "config-shield: WARNING — no HMAC key available for verify. Falling back to plain sha256." >&2
  return 1
}

# ── Canonicalise content ──
_canonical_content() {
  local file="$1"
  case "$file" in
    *.json)
      if command -v jq >/dev/null 2>&1; then
        if jq -c -S . "$file" 2>/dev/null; then
          return 0
        fi
      fi
      ;;
  esac
  cat "$file"
}

CANONICAL="$(_canonical_content "$CONFIG_FILE")"

if KEY="$(_signing_key)"; then
  EXPECTED=$(printf "%s" "$CANONICAL" \
    | openssl dgst -sha256 -mac hmac -macopt "key:$KEY" -binary \
    | openssl base64 -A)
else
  EXPECTED=$(printf "%s" "$CANONICAL" \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A)
fi

STORED="$(cat "$SIG_FILE")"

if [[ "$EXPECTED" == "$STORED" ]]; then
  exit 0
else
  exit 1
fi
