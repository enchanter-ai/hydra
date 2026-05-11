#!/usr/bin/env bash
# capability-shield: sign a SKILL.md so verify-skill.sh can detect mutation.
#
# Closes R-018 (F-PT-14 / F-PT-15 / F-PT-46): SKILL.md is the capability trust
# root but was previously unsigned and mtime-selected — a TOCTOU self-mutation
# primitive. With a signed sidecar, verify-before-eval refuses to evaluate
# allowed-tools for a SKILL.md whose canonical content has drifted from the
# signed manifest.
#
# Usage:
#   sign-skill.sh <SKILL.md-path>
#
# Output:
#   Writes <SKILL.md>.sig — base64(HMAC-SHA-256(KEY, canonical_content))
#   where canonical_content = LF-normalized bytes of the SKILL.md.
#
# Key sourcing mirrors audit-trail/scripts/chain-helpers.sh exactly:
#   1. $HYDRA_AUDIT_HMAC_KEY env var (operator-rotated, preferred)
#   2. state/hmac-key.bin (auto-generated 256-bit hex, mode 0600)
#   3. fall through to plain SHA-256 with a LOUD WARNING (last-resort;
#      surfaces the gap rather than silently weakening the signature)
#
# Exit codes:
#   0  signed successfully (sidecar written)
#   1  argument error / file not found / openssl missing
#   2  could not derive key AND fallback also failed

set -uo pipefail

usage() {
  cat >&2 <<EOF
usage: sign-skill.sh <SKILL.md-path>

Writes a sidecar <SKILL.md>.sig containing base64(HMAC-SHA-256) of the
file's LF-normalized content, using the same key-sourcing convention as
hydra/plugins/audit-trail/scripts/chain-helpers.sh.

Key sources (in priority order):
  1. \$HYDRA_AUDIT_HMAC_KEY env var
  2. <plugin-root>/state/hmac-key.bin (auto-created 0600 if missing)
  3. plain SHA-256 fallback with a LOUD WARNING (chain is NOT HMAC-protected)
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

SKILL_MD="$1"
if [[ ! -f "$SKILL_MD" ]]; then
  echo "sign-skill: not a file: $SKILL_MD" >&2
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "sign-skill: openssl not on PATH" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$SCRIPT_DIR/../state"
KEY_FILE="$STATE_DIR/hmac-key.bin"

_shield_key() {
  if [[ -n "${HYDRA_AUDIT_HMAC_KEY:-}" ]]; then
    printf "%s" "$HYDRA_AUDIT_HMAC_KEY"
    return 0
  fi
  if [[ -r "$KEY_FILE" && -s "$KEY_FILE" ]]; then
    cat "$KEY_FILE"
    return 0
  fi
  if mkdir -p "$STATE_DIR" 2>/dev/null && \
     openssl rand -hex 32 > "$KEY_FILE" 2>/dev/null && \
     chmod 0600 "$KEY_FILE" 2>/dev/null; then
    cat "$KEY_FILE"
    return 0
  fi
  echo "sign-skill: WARNING — no HMAC key available (env unset, state/hmac-key.bin uncreatable). Falling back to plain sha256 — SKILL.md signature is NOT cryptographically tamper-evident. Set HYDRA_AUDIT_HMAC_KEY or grant write to state/." >&2
  return 1
}

# Canonical content = LF-normalized bytes (strip CR for cross-platform parity).
_canonical_content() {
  # tr -d '\r' is portable; sed -i would touch the source file.
  tr -d '\r' < "$SKILL_MD"
}

if KEY="$(_shield_key)"; then
  SIG="$(_canonical_content \
    | openssl dgst -sha256 -mac hmac -macopt "key:$KEY" -binary \
    | openssl base64 -A)"
else
  SIG="$(_canonical_content \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A)"
fi

if [[ -z "$SIG" ]]; then
  echo "sign-skill: failed to compute signature" >&2
  exit 2
fi

SIG_PATH="${SKILL_MD}.sig"
printf "%s\n" "$SIG" > "$SIG_PATH" || {
  echo "sign-skill: could not write $SIG_PATH" >&2
  exit 2
}

echo "sign-skill: wrote $SIG_PATH"
exit 0
