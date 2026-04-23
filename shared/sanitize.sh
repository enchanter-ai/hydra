#!/usr/bin/env bash
# Hydra shared sanitization utilities

sanitize_path() {
  local path="$1"
  local project_root="${2:-}"
  [[ -z "$path" ]] && return 1

  # Decode URL-encoded path traversal
  # Two-pass decode to catch double-encoding (%252e → %2e → .)
  local decoded
  decoded=$(printf "%s" "$path" \
    | sed -e 's/%25/%/g' -e 's/%2[eE]/./g' -e 's/%2[fF]/\//g' \
    | sed -e 's/%25/%/g' -e 's/%2[eE]/./g' -e 's/%2[fF]/\//g')

  # Block path traversal (..)
  if [[ "$decoded" == *".."* ]]; then return 1; fi

  # Block null bytes
  if printf "%s" "$decoded" | grep -qP '\x00' 2>/dev/null; then return 1; fi

  # If project_root is set, ensure path is under it
  if [[ -n "$project_root" ]]; then
    case "$decoded" in
      /*) ;; # already absolute — OK
      *)  decoded="${project_root}/${decoded}" ;;
    esac
    # Normalize away single dots
    decoded=$(printf "%s" "$decoded" | sed 's|/\./|/|g; s|/\.$||')
    case "$decoded" in
      "${project_root}"*) ;; # under project root — OK
      *) return 1 ;;
    esac
  fi

  echo "$decoded"
  return 0
}

validate_json() {
  printf "%s" "$1" | jq empty >/dev/null 2>&1
}

mask_secret() {
  # Mask a string: show first N and last N chars only
  # NEVER log full secret values
  local value="$1"
  local prefix_len="${HYDRA_MASK_PREFIX_LEN:-4}"
  local suffix_len="${HYDRA_MASK_SUFFIX_LEN:-4}"
  local min_len=$(( prefix_len + suffix_len + 3 ))

  if [[ ${#value} -lt $min_len ]]; then
    printf "[REDACTED]"
    return 0
  fi

  local prefix="${value:0:$prefix_len}"
  local suffix="${value: -$suffix_len}"
  printf "%s...%s" "$prefix" "$suffix"
}

sanitize_for_log() {
  # Redact known secret patterns from log output
  printf "%s" "$1" \
    | sed -E \
      -e 's/(AKIA[0-9A-Z]{16})/[AWS_KEY_REDACTED]/g' \
      -e 's/(sk-ant-[a-zA-Z0-9_-]+)/[ANTHROPIC_KEY_REDACTED]/g' \
      -e 's/(sk-[a-zA-Z0-9]{20,})/[OPENAI_KEY_REDACTED]/g' \
      -e 's/(ghp_[a-zA-Z0-9]{36})/[GITHUB_TOKEN_REDACTED]/g' \
      -e 's/(gho_[a-zA-Z0-9]{36})/[GITHUB_OAUTH_REDACTED]/g' \
      -e 's/(ghs_[a-zA-Z0-9]{36})/[GITHUB_SERVER_REDACTED]/g' \
      -e 's/(glpat-[a-zA-Z0-9_-]{20,})/[GITLAB_TOKEN_REDACTED]/g' \
      -e 's/(eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,})/[JWT_REDACTED]/g' \
      -e 's/(password|secret|token|api_key|apikey|api-key)=[^ ]*/\1=[REDACTED]/gi' \
      -e 's/(Bearer\s+)[a-zA-Z0-9._-]+/\1[REDACTED]/gi'
}

is_test_file() {
  # Check if a file path looks like a test/fixture file
  # Use || true to prevent ERR trap from firing on grep no-match
  local path="$1"
  if printf "%s" "$path" | grep -qiE '(test|spec|fixture|mock|example|__tests__|__mocks__|testdata|fake|stub|sample)' 2>/dev/null; then
    return 0
  else
    return 1
  fi
}
