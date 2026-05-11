#!/usr/bin/env bash
# audit-trail: HMAC-SHA-256 hash-chain helpers for tamper-evident JSONL.
#
# HARDENING (post pentest finding F-PT-16, 2026-05-11):
#   Earlier revision used plain `openssl dgst -sha256` which an attacker
#   with write access could re-compute trivially. Now uses HMAC-SHA-256
#   with a secret key, sourced in priority order:
#     1. $HYDRA_AUDIT_HMAC_KEY env var (operator-rotated, preferred)
#     2. state/hmac-key.bin (auto-generated 256-bit key, mode 0600)
#     3. fall through to plain SHA-256 with a LOUD WARNING (last-resort,
#        only when key file can't be created — surfaces the gap rather
#        than silently weakening the chain).
#
# Each audit line carries a `prev_hash` field — base64(hmac_sha256(KEY, canonical_json(prev))).
# First line: literal "GENESIS".
#
# Provides:
#   compute_prev_hash <file>   → base64(hmac_sha256(KEY, canonical_json(last_line))) | "GENESIS"
#   verify_chain <file>        → 0 on intact chain, non-zero on first mismatch
#
# Pure shell + jq + openssl. State only in state/hmac-key.bin.

# ── Key resolution ─────────────────────────────────────────────────────────
_audit_key() {
  if [[ -n "${HYDRA_AUDIT_HMAC_KEY:-}" ]]; then
    printf "%s" "$HYDRA_AUDIT_HMAC_KEY"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local state_dir="$script_dir/../state"
  local key_file="$state_dir/hmac-key.bin"

  if [[ -r "$key_file" && -s "$key_file" ]]; then
    cat "$key_file"
    return 0
  fi

  # Try to generate one.
  if mkdir -p "$state_dir" 2>/dev/null && \
     openssl rand -hex 32 > "$key_file" 2>/dev/null && \
     chmod 0600 "$key_file" 2>/dev/null; then
    cat "$key_file"
    return 0
  fi

  # Last resort: emit a loud warning and return empty (caller falls back to plain sha256).
  echo "audit-trail: WARNING — no HMAC key available (env unset, state/hmac-key.bin uncreatable). Falling back to plain sha256 — chain is NOT cryptographically tamper-evident. Set HYDRA_AUDIT_HMAC_KEY env var or grant write to state/." >&2
  return 1
}

_hash_canonical() {
  local canonical="$1"
  local key
  if key="$(_audit_key)"; then
    printf "%s" "$canonical" \
      | openssl dgst -sha256 -mac hmac -macopt "key:$key" -binary \
      | openssl base64 -A
  else
    printf "%s" "$canonical" \
      | openssl dgst -sha256 -binary \
      | openssl base64 -A
  fi
}

# Compute the prev_hash a NEW appended line should carry.
# Reads the last non-empty line, canonicalises via `jq -c -S`, HMACs with key,
# emits base64 (no newline). If the file is missing or empty → "GENESIS".
compute_prev_hash() {
  local file="$1"
  if [[ ! -s "$file" ]]; then
    printf "GENESIS"
    return 0
  fi

  local last
  last=$(awk 'NF{line=$0} END{print line}' "$file")
  if [[ -z "$last" ]]; then
    printf "GENESIS"
    return 0
  fi

  # Canonicalise: sort keys, strip whitespace. If the line is not valid JSON,
  # treat its raw bytes as the canonical form (don't crash the chain).
  local canonical
  if canonical=$(printf "%s" "$last" | jq -c -S . 2>/dev/null); then
    :
  else
    canonical="$last"
  fi

  _hash_canonical "$canonical"
}

# Walk the chain from the top. For each line N (1-indexed):
#   line 1 must have prev_hash == "GENESIS"
#   line N (N>1) must have prev_hash == base64(hmac_sha256(KEY, canonical_json(line N-1)))
#
# Returns 0 if every line passes, non-zero on the first mismatch. On failure
# emits a one-line diagnostic to stderr:
#   chain broken at line <N>: expected <hash> got <hash>
verify_chain() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "verify_chain: file not found: $file" >&2
    return 2
  fi
  if [[ ! -s "$file" ]]; then
    return 0
  fi

  local lineno=0
  local expected="GENESIS"
  local actual
  local canonical

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    lineno=$((lineno + 1))

    actual=$(printf "%s" "$line" | jq -r '.prev_hash // empty' 2>/dev/null)
    if [[ -z "$actual" ]]; then
      echo "chain broken at line $lineno: missing prev_hash field" >&2
      return 1
    fi

    if [[ "$actual" != "$expected" ]]; then
      echo "chain broken at line $lineno: expected $expected got $actual" >&2
      return 1
    fi

    # Compute the hash this line CONTRIBUTES for the next iteration.
    if canonical=$(printf "%s" "$line" | jq -c -S . 2>/dev/null); then
      :
    else
      canonical="$line"
    fi
    expected=$(_hash_canonical "$canonical")
  done < "$file"

  return 0
}
