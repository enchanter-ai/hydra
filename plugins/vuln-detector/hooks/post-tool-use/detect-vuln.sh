#!/usr/bin/env bash
# vuln-detector: PostToolUse hook
# Implements R3 (OWASP Vulnerability Graph).
# Scans file writes for CWE-mapped vulnerability patterns.
# Fires on Write/Edit/MultiEdit.
# MUST exit 0 always.


# Subagent recursion guard — see shared/conduct/hooks.md
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

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
HOOK_INPUT=$(hydra_read_stdin 1048576)

if ! validate_json "$HOOK_INPUT"; then
  exit 0
fi

# Extract fields
PARSED=$(printf "%s" "$HOOK_INPUT" | jq -r '[.tool_name // "", .tool_input.file_path // "", .transcript_path // ""] | join("\t")' 2>/dev/null)
TOOL_NAME=$(printf "%s" "$PARSED" | cut -f1)
FILE_PATH=$(printf "%s" "$PARSED" | cut -f2)

if [[ -z "$TOOL_NAME" ]] || [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# ── Sanitize path ──
DECODED=$(printf "%s" "$FILE_PATH" | sed -e 's/%2[eE]/./g' -e 's/%2[fF]/\//g' -e 's/%25/%/g')
if [[ "$DECODED" == *".."* ]]; then exit 0; fi

# ── Skip binary files ──
if [[ -f "$FILE_PATH" ]] && hydra_is_binary "$FILE_PATH"; then
  exit 0
fi

# ── Skip if file doesn't exist or is empty ──
if [[ ! -f "$FILE_PATH" ]] || [[ ! -s "$FILE_PATH" ]]; then
  exit 0
fi

# ── Detect file language from extension ──
BASENAME=$(basename "$FILE_PATH" 2>/dev/null || true)
EXTENSION="${BASENAME##*.}"

LANGUAGE=""
case "$EXTENSION" in
  js|jsx|mjs|cjs) LANGUAGE="javascript" ;;
  ts|tsx|mts|cts) LANGUAGE="typescript" ;;
  py|pyw) LANGUAGE="python" ;;
  java) LANGUAGE="java" ;;
  rb|rake) LANGUAGE="ruby" ;;
  php) LANGUAGE="php" ;;
  go) LANGUAGE="go" ;;
  rs) LANGUAGE="rust" ;;
  *) exit 0 ;;  # Skip non-code files
esac

# ── Load vuln patterns for this language ──
PATTERNS_FILE="${SHARED_DIR}/${HYDRA_PATTERNS_VULNS}"
if [[ ! -f "$PATTERNS_FILE" ]]; then exit 0; fi

# Extract patterns applicable to this language
# Build a temp file with pattern|id|cwe|severity|description tuples
LANG_PATTERNS="${HYDRA_CACHE_PREFIX}vulns-${LANGUAGE}-$$.tmp"
jq -r --arg lang "$LANGUAGE" \
  '.[] | select(.language | index($lang)) | [.pattern, .id, .cwe, .severity, .description] | join("\t")' \
  "$PATTERNS_FILE" 2>/dev/null > "$LANG_PATTERNS" || exit 0

if [[ ! -s "$LANG_PATTERNS" ]]; then
  rm -f "$LANG_PATTERNS" 2>/dev/null
  exit 0
fi

# ── Scan file against each pattern ──
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_DIR="${PLUGIN_ROOT}/state"
FINDING_COUNT=0
SHORT_FILE=$(basename "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

# Cap file read at 2000 lines
FILE_CONTENT="${HYDRA_CACHE_PREFIX}vuln-content-$$.tmp"
head -2000 "$FILE_PATH" > "$FILE_CONTENT" 2>/dev/null

while IFS=$'\t' read -r PATTERN VULN_ID CWE SEVERITY DESCRIPTION; do
  [[ -z "$PATTERN" ]] && continue

  # Convert PCRE syntax to ERE equivalents for grep -E portability
  PATTERN=$(printf "%s" "$PATTERN" | sed 's/\\s/[[:space:]]/g; s/(?:/(/g; s/(?!/(/g; s/(?<=/(/g')

  # grep for the pattern
  MATCHES=$(grep -nE "$PATTERN" "$FILE_CONTENT" 2>/dev/null | head -5 || true)
  [[ -z "$MATCHES" ]] && continue

  while IFS=: read -r LINE_NUM _MATCH_CONTENT; do
    [[ -z "$LINE_NUM" ]] && continue
    FINDING_COUNT=$((FINDING_COUNT + 1))

    # ── Log to audit trail ──
    AUDIT_ENTRY=$(jq -cn \
      --arg event "vuln_detected" \
      --arg ts "$TIMESTAMP" \
      --arg file "$FILE_PATH" \
      --argjson line "$LINE_NUM" \
      --arg vuln_id "$VULN_ID" \
      --arg cwe "$CWE" \
      --arg severity "$SEVERITY" \
      --arg description "$DESCRIPTION" \
      --arg language "$LANGUAGE" \
      --arg tool "$TOOL_NAME" \
      '{event:$event, ts:$ts, file:$file, line:$line, vuln_id:$vuln_id, cwe:$cwe, severity:$severity, description:$description, language:$language, tool:$tool}')

    log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"

    # ── stderr output for Claude ──
    if [[ "$SEVERITY" == "critical" ]]; then
      printf "[Hydra] CRITICAL VULN: %s — %s in %s:%s\n" "$CWE" "$DESCRIPTION" "$SHORT_FILE" "$LINE_NUM" >&2
    elif [[ "$SEVERITY" == "high" ]]; then
      printf "[Hydra] VULN: %s — %s in %s:%s\n" "$CWE" "$DESCRIPTION" "$SHORT_FILE" "$LINE_NUM" >&2
    fi

    # Cap at 10 findings per file
    if [[ $FINDING_COUNT -ge 10 ]]; then
      printf "[Hydra] ...and more. Run /hydra:vulns for full scan.\n" >&2
      break 2
    fi
  done <<< "$MATCHES"
done < "$LANG_PATTERNS"

# ── Cleanup ──
rm -f "$LANG_PATTERNS" "$FILE_CONTENT" 2>/dev/null

# ── Log summary metric ──
if [[ $FINDING_COUNT -gt 0 ]]; then
  SUMMARY=$(jq -cn \
    --arg event "vuln_scan_complete" \
    --arg ts "$TIMESTAMP" \
    --arg file "$FILE_PATH" \
    --argjson count "$FINDING_COUNT" \
    --arg language "$LANGUAGE" \
    '{event:$event, ts:$ts, file:$file, findings:$count, language:$language}')

  log_metric "${STATE_DIR}/metrics.jsonl" "$SUMMARY"
fi

exit 0
