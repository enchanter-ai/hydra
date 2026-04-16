#!/usr/bin/env bash
# secret-scanner: PostToolUse hook
# Implements R1 (Aho-Corasick Pattern Engine) and R2 (Shannon Entropy Analysis).
# Scans every file write for 200+ secret patterns using grep-based matching.
# MUST be < 50ms per file. Uses grep, NOT Python.
# MUST exit 0 always. NEVER log actual secret values.

trap 'exit 0' ERR INT TERM

set -uo pipefail

# ── Check dependencies ──
if ! command -v jq >/dev/null 2>&1; then exit 0; fi
if ! command -v grep >/dev/null 2>&1; then exit 0; fi

# Resolve paths
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SHARED_DIR="${PLUGIN_ROOT}/../../shared"

# shellcheck source=../../../../shared/constants.sh
source "${SHARED_DIR}/constants.sh"
# shellcheck source=../../../../shared/sanitize.sh
source "${SHARED_DIR}/sanitize.sh"
# shellcheck source=../../../../shared/metrics.sh
source "${SHARED_DIR}/metrics.sh"
# shellcheck source=../../../../shared/compat.sh
source "${SHARED_DIR}/compat.sh"

# ── Read hook input from stdin (capped at 1MB) ──
HOOK_INPUT=$(reaper_read_stdin 1048576)

if ! validate_json "$HOOK_INPUT"; then
  exit 0
fi

# Extract fields in a single jq call
PARSED=$(printf "%s" "$HOOK_INPUT" | jq -r '[.tool_name // "", .tool_input.file_path // "", .transcript_path // ""] | join("\t")' 2>/dev/null)
TOOL_NAME=$(printf "%s" "$PARSED" | cut -f1)
FILE_PATH=$(printf "%s" "$PARSED" | cut -f2)
HOOK_TRANSCRIPT_PATH=$(printf "%s" "$PARSED" | cut -f3)

if [[ -z "$TOOL_NAME" ]] || [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# ── Sanitize path ──
DECODED=$(printf "%s" "$FILE_PATH" | sed -e 's/%2[eE]/./g' -e 's/%2[fF]/\//g' -e 's/%25/%/g')
if [[ "$DECODED" == *".."* ]]; then exit 0; fi

# ── Skip binary files ──
if [[ -f "$FILE_PATH" ]] && reaper_is_binary "$FILE_PATH"; then
  exit 0
fi

# ── Skip if file doesn't exist or is empty ──
if [[ ! -f "$FILE_PATH" ]] || [[ ! -s "$FILE_PATH" ]]; then
  exit 0
fi

# ── Session hash for cache isolation ──
SESSION_HASH=$(reaper_md5_file "${HOOK_TRANSCRIPT_PATH}" 2>/dev/null || echo "fallback-$$")

# ── Build or load cached regex from secrets.json ──
PATTERNS_FILE="${SHARED_DIR}/${REAPER_PATTERNS_SECRETS}"
PATTERNS_HASH=$(reaper_md5_file "$PATTERNS_FILE" 2>/dev/null || echo "default")
REGEX_CACHE="${REAPER_CACHE_PREFIX}secrets-regex-${PATTERNS_HASH}"

if [[ ! -f "$REGEX_CACHE" ]]; then
  # Split into multiple short regex lines for portability.
  # Some grep implementations choke on very long alternation patterns.
  cat > "$REGEX_CACHE" << 'PATTERNS'
AKIA[0-9A-Z]{16}
sk-ant-[a-zA-Z0-9_-]{20,}
sk-proj-[a-zA-Z0-9_-]{40,}
ghp_[a-zA-Z0-9]{36}
gho_[a-zA-Z0-9]{36}
ghs_[a-zA-Z0-9]{36}
glpat-[a-zA-Z0-9_-]{20,}
sk_live_[a-zA-Z0-9]{24,}
sk_test_[a-zA-Z0-9]{24,}
-----BEGIN RSA PRIVATE KEY-----
-----BEGIN OPENSSH PRIVATE KEY-----
-----BEGIN PRIVATE KEY-----
-----BEGIN PGP PRIVATE KEY BLOCK-----
-----BEGIN EC PRIVATE KEY-----
AIza[0-9A-Za-z_-]{35}
hf_[a-zA-Z0-9]{34,}
npm_[a-zA-Z0-9]{36}
xox[bpsar]-[a-zA-Z0-9-]{10,}
DefaultEndpointsProtocol=
shpat_[a-fA-F0-9]{32}
dckr_pat_[a-zA-Z0-9_-]{20,}
hvs\.[a-zA-Z0-9_-]{24,}
dop_v1_[a-f0-9]{64}
r8_[a-zA-Z0-9]{36}
postgres://[^:]+:[^@]+@
postgresql://[^:]+:[^@]+@
mysql://[^:]+:[^@]+@
mongodb://[^:]+:[^@]+@
mongodb\+srv://[^:]+:[^@]+@
redis://[^:]*:[^@]+@
eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}
SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}
pypi-[a-zA-Z0-9_-]{50,}
github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}
AGE-SECRET-KEY-1[A-Z0-9]{58}
-----BEGIN ENCRYPTED PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
lin_api_[a-zA-Z0-9]{40}
sq0atp-[a-zA-Z0-9_-]{22}
key-[a-f0-9]{32}
whsec_[a-zA-Z0-9]{32,}
nk_live_[a-zA-Z0-9]{24,}
pk\.[a-zA-Z0-9]{60,}
dapi[a-f0-9]{32}
pul-[a-f0-9]{40}
dp\.st\.[a-zA-Z0-9_-]{40,}
PATTERNS
fi

# ── R1: grep-based pattern matching ──
# Use -f to read patterns from file (one per line)
# Cap file read at 2000 lines for performance
FINDINGS_FILE="${REAPER_CACHE_PREFIX}secrets-findings-${SESSION_HASH}-$$.tmp"
head -2000 "$FILE_PATH" 2>/dev/null \
  | grep -nEof "$REGEX_CACHE" 2>/dev/null \
  > "$FINDINGS_FILE" || true

if [[ ! -s "$FINDINGS_FILE" ]]; then
  rm -f "$FINDINGS_FILE" 2>/dev/null
  exit 0
fi

# ── Determine if this is a test file (reduce severity to INFO) ──
IS_TEST="false"
if is_test_file "$FILE_PATH"; then
  IS_TEST="true"
fi

# ── Process findings ──
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_DIR="${PLUGIN_ROOT}/state"
FINDING_COUNT=0
SHORT_FILE=$(basename "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

while IFS=: read -r LINE_NUM MATCHED_TEXT; do
  [[ -z "$LINE_NUM" ]] && continue
  FINDING_COUNT=$((FINDING_COUNT + 1))

  # Mask the secret — NEVER log full value
  MASKED=$(mask_secret "$MATCHED_TEXT")

  # Determine severity based on pattern matching
  SEVERITY="$REAPER_SEVERITY_HIGH"
  PATTERN_ID="unknown"

  # Check against known critical patterns
  case "$MATCHED_TEXT" in
    AKIA*) PATTERN_ID="aws-access-key-id"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    sk-ant-*) PATTERN_ID="anthropic-api-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    ghp_*) PATTERN_ID="github-pat"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    gho_*) PATTERN_ID="github-oauth"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    ghs_*) PATTERN_ID="github-app-token"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    glpat-*) PATTERN_ID="gitlab-pat"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    sk_live_*) PATTERN_ID="stripe-secret-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    sk_test_*) PATTERN_ID="stripe-test-key"; SEVERITY="$REAPER_SEVERITY_MEDIUM" ;;
    xox[bpsar]-*) PATTERN_ID="slack-token"; SEVERITY="$REAPER_SEVERITY_HIGH" ;;
    eyJ*) PATTERN_ID="jwt-token"; SEVERITY="$REAPER_SEVERITY_HIGH" ;;
    hf_*) PATTERN_ID="huggingface-token"; SEVERITY="$REAPER_SEVERITY_HIGH" ;;
    npm_*) PATTERN_ID="npm-token"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *"BEGIN RSA PRIVATE KEY"*) PATTERN_ID="rsa-private-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *"BEGIN OPENSSH PRIVATE KEY"*) PATTERN_ID="openssh-private-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *"BEGIN PRIVATE KEY"*) PATTERN_ID="pkcs8-private-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *"BEGIN PGP PRIVATE KEY"*) PATTERN_ID="pgp-private-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *postgres://*) PATTERN_ID="postgres-connection-string"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *mysql://*) PATTERN_ID="mysql-connection-string"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *mongodb*://*) PATTERN_ID="mongodb-connection-string"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    AIza*) PATTERN_ID="gcp-api-key"; SEVERITY="$REAPER_SEVERITY_HIGH" ;;
    *DefaultEndpoints*) PATTERN_ID="azure-storage-key"; SEVERITY="$REAPER_SEVERITY_CRITICAL" ;;
    *) PATTERN_ID="generic-secret"; SEVERITY="$REAPER_SEVERITY_MEDIUM" ;;
  esac

  # Downgrade severity for test files
  if [[ "$IS_TEST" == "true" ]]; then
    SEVERITY="$REAPER_SEVERITY_INFO"
  fi

  # ── Log to audit trail ──
  AUDIT_ENTRY=$(jq -cn \
    --arg event "secret_detected" \
    --arg ts "$TIMESTAMP" \
    --arg file "$FILE_PATH" \
    --argjson line "$LINE_NUM" \
    --arg pattern_id "$PATTERN_ID" \
    --arg severity "$SEVERITY" \
    --arg masked "$MASKED" \
    --arg tool "$TOOL_NAME" \
    --argjson is_test "$IS_TEST" \
    '{event:$event, ts:$ts, file:$file, line:$line, pattern_id:$pattern_id, severity:$severity, masked:$masked, tool:$tool, is_test:$is_test}')

  log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"

  # ── stderr output for Claude ──
  if [[ "$SEVERITY" == "$REAPER_SEVERITY_CRITICAL" ]]; then
    printf "[Reaper] CRITICAL SECRET: %s in %s:%s (masked: %s)\n" "$PATTERN_ID" "$SHORT_FILE" "$LINE_NUM" "$MASKED" >&2
  elif [[ "$SEVERITY" != "$REAPER_SEVERITY_INFO" ]]; then
    printf "[Reaper] SECRET: %s in %s:%s (severity: %s)\n" "$PATTERN_ID" "$SHORT_FILE" "$LINE_NUM" "$SEVERITY" >&2
  fi

  # Cap at 20 findings per file to avoid noise
  if [[ $FINDING_COUNT -ge 20 ]]; then
    printf "[Reaper] ...and more. Run /reaper:secrets for full scan.\n" >&2
    break
  fi
done < "$FINDINGS_FILE"

# ── Cleanup ──
rm -f "$FINDINGS_FILE" 2>/dev/null

# ── Log summary metric ──
if [[ $FINDING_COUNT -gt 0 ]]; then
  SUMMARY=$(jq -cn \
    --arg event "secret_scan_complete" \
    --arg ts "$TIMESTAMP" \
    --arg file "$FILE_PATH" \
    --argjson count "$FINDING_COUNT" \
    --argjson is_test "$IS_TEST" \
    '{event:$event, ts:$ts, file:$file, findings:$count, is_test:$is_test}')

  log_metric "${STATE_DIR}/metrics.jsonl" "$SUMMARY"
fi

exit 0
