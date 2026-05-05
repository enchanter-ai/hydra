#!/usr/bin/env bash
# audit-trail: hash-chain helpers for tamper-evident JSONL.
#
# Each audit line carries a `prev_hash` field — the SHA-256 (base64) of the
# canonical-JSON of the previous line, or the literal string "GENESIS" for
# the first line in the file. A consumer can re-compute the chain to detect
# in-place edits, deletes, or insertions.
#
# Provides two functions:
#   compute_prev_hash <file>   → echoes base64(sha256(canonical_json(last_line)))
#                                or "GENESIS" if the file is empty/missing
#   verify_chain <file>        → walks the log; returns 0 on intact chain,
#                                non-zero with offending line number + hash
#                                mismatch on stderr otherwise
#
# Both are pure shell + standard tools (jq, openssl). No state outside argv.

# Compute the prev_hash a NEW appended line should carry.
# Reads the last non-empty line, canonicalises via `jq -c -S`, sha256sums,
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

  printf "%s" "$canonical" \
    | openssl dgst -sha256 -binary \
    | openssl base64 -A
}

# Walk the chain from the top. For each line N (1-indexed):
#   line 1 must have prev_hash == "GENESIS"
#   line N (N>1) must have prev_hash == base64(sha256(canonical_json(line N-1)))
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
  local prev_canonical=""
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
    expected=$(printf "%s" "$canonical" \
      | openssl dgst -sha256 -binary \
      | openssl base64 -A)
    prev_canonical="$canonical"
  done < "$file"

  return 0
}
