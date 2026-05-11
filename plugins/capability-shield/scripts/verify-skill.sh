#!/usr/bin/env bash
# capability-shield: verify a SKILL.md against its signed sidecar.
#
# Closes R-018 — verify-before-eval gate. Recomputes the HMAC-SHA-256
# over the LF-normalized SKILL.md content and compares it to the base64
# value stored in <SKILL.md>.sig. If they match, the SKILL.md has not been
# mutated since signing; shield-check.py is safe to parse its frontmatter
# and enforce allowed-tools.
#
# Usage:
#   verify-skill.sh <SKILL.md-path>
#
# Exit codes:
#   0  signature present and matches (verified)
#   1  signature present but DOES NOT match (tampered / re-saved without resign)
#   2  no sidecar .sig present (never signed, or sig deleted)
#
# Quiet by default; -v for verbose. Diagnostics go to stderr; nothing on stdout.
#
# Key sourcing mirrors sign-skill.sh / chain-helpers.sh.

set -uo pipefail

VERBOSE=0
if [[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]]; then
  VERBOSE=1
  shift
fi

if [[ $# -ne 1 ]]; then
  echo "usage: verify-skill.sh [-v] <SKILL.md-path>" >&2
  exit 1
fi

SKILL_MD="$1"
if [[ ! -f "$SKILL_MD" ]]; then
  echo "verify-skill: not a file: $SKILL_MD" >&2
  exit 1
fi
if ! command -v openssl >/dev/null 2>&1; then
  echo "verify-skill: openssl not on PATH" >&2
  exit 1
fi

SIG_PATH="${SKILL_MD}.sig"
if [[ ! -f "$SIG_PATH" ]]; then
  [[ $VERBOSE -eq 1 ]] && echo "verify-skill: no sidecar at $SIG_PATH" >&2
  exit 2
fi
if [[ ! -s "$SIG_PATH" ]]; then
  [[ $VERBOSE -eq 1 ]] && echo "verify-skill: empty sidecar at $SIG_PATH" >&2
  exit 2
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
  # Do NOT auto-generate during verify — would create a key that can't match
  # an existing sidecar. Just warn and fall through to plain sha256.
  echo "verify-skill: WARNING — no HMAC key available; comparing against plain sha256. If the sidecar was HMAC-signed, this will report mismatch." >&2
  return 1
}

_canonical_content() {
  tr -d '\r' < "$SKILL_MD"
}

if KEY="$(_shield_key)"; then
  COMPUTED="$(_canonical_content \
    | openssl dgst -sha256 -mac hmac -macopt "key:$KEY" -binary \
    | openssl base64 -A)"
else
  COMPUTED="$(_canonical_content \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A)"
fi

# Read the stored signature; trim whitespace/newline.
STORED="$(tr -d '[:space:]' < "$SIG_PATH")"

if [[ -z "$COMPUTED" || -z "$STORED" ]]; then
  echo "verify-skill: failed to compute or read signature" >&2
  exit 1
fi

if [[ "$COMPUTED" == "$STORED" ]]; then
  [[ $VERBOSE -eq 1 ]] && echo "verify-skill: OK $SKILL_MD" >&2
  exit 0
fi

[[ $VERBOSE -eq 1 ]] && echo "verify-skill: MISMATCH $SKILL_MD (expected $STORED, computed $COMPUTED)" >&2
exit 1
