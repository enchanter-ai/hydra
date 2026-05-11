#!/usr/bin/env bash
# config-shield: sign a single config file with HMAC-SHA-256.
#
# Computes HMAC-SHA-256 of the canonical content of <config-file> and writes
# the result (base64, no newline) into <config-file>.sig as the sidecar.
#
# Canonicalisation:
#   - .json files: jq -c -S (sort keys, compact, deterministic)
#   - everything else: raw bytes
#
# Key sourcing — identical priority to audit-trail/chain-helpers.sh:
#   1. $HYDRA_AUDIT_HMAC_KEY env var (operator-rotated, preferred)
#   2. <plugin-state>/hmac-key.bin (auto-generated 256-bit, mode 0600)
#   3. fall through to plain SHA-256 with a LOUD WARNING — surfaces the gap
#      rather than silently weakening the signature.
#
# Usage: bash sign-config.sh <config-file>
# Exit: 0 on success; 1 on bad usage / missing file.

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <config-file>" >&2
  exit 1
fi

CONFIG_FILE="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "sign-config: file not found: $CONFIG_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../state"

# ── Key resolution (mirrors audit-trail/chain-helpers.sh) ──
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

  if mkdir -p "$STATE_DIR" 2>/dev/null && \
     openssl rand -hex 32 > "$key_file" 2>/dev/null && \
     chmod 0600 "$key_file" 2>/dev/null; then
    cat "$key_file"
    return 0
  fi

  echo "config-shield: WARNING — no HMAC key available (env unset, state/hmac-key.bin uncreatable). Falling back to plain sha256 — signature is NOT cryptographically tamper-evident. Set HYDRA_AUDIT_HMAC_KEY env var or grant write to state/." >&2
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

# ── Compute signature ──
CANONICAL="$(_canonical_content "$CONFIG_FILE")"

if KEY="$(_signing_key)"; then
  SIG=$(printf "%s" "$CANONICAL" \
    | openssl dgst -sha256 -mac hmac -macopt "key:$KEY" -binary \
    | openssl base64 -A)
else
  SIG=$(printf "%s" "$CANONICAL" \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A)
fi

printf "%s" "$SIG" > "${CONFIG_FILE}.sig"

echo "signed: $CONFIG_FILE → ${CONFIG_FILE}.sig"
exit 0
