#!/usr/bin/env bash
# config-shield: SessionStart hook
# Implements R5 (Config Poisoning Detection).
# Scans repository for malicious config files at session start.
# Detects CVE-2025-59536, CVE-2026-21852, MCP consent bypass, etc.
# Advisory only — exit 0 always. Never blocks.

trap 'exit 0' ERR INT TERM

set -uo pipefail

# ── Check dependencies ──
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

# Resolve paths
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SHARED_DIR="${PLUGIN_ROOT}/../../shared"

# shellcheck source=../../../../shared/constants.sh
source "${SHARED_DIR}/constants.sh"
# shellcheck source=../../../../shared/sanitize.sh
source "${SHARED_DIR}/sanitize.sh"
# shellcheck source=../../../../shared/metrics.sh
source "${SHARED_DIR}/metrics.sh"

# ── Read hook input from stdin ──
HOOK_INPUT=$(head -c 1048576 2>/dev/null)

if [[ -z "$HOOK_INPUT" ]]; then
  # SessionStart may not pass JSON — use cwd as project root
  PROJECT_ROOT="$(pwd)"
else
  if validate_json "$HOOK_INPUT"; then
    PROJECT_ROOT=$(printf "%s" "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null)
  fi
  PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
fi

if [[ -z "$PROJECT_ROOT" ]] || [[ ! -d "$PROJECT_ROOT" ]]; then
  exit 0
fi

# ── Load attack patterns ──
PATTERNS_FILE="${SHARED_DIR}/${HYDRA_PATTERNS_CONFIG}"
if [[ ! -f "$PATTERNS_FILE" ]]; then exit 0; fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_DIR="${PLUGIN_ROOT}/state"
FINDING_COUNT=0

# ── Scan each known config file pattern ──
while IFS=$'\t' read -r FILE_PATTERN CHECK_TYPE PATTERN CVE SEVERITY DESCRIPTION; do
  [[ -z "$FILE_PATTERN" ]] && continue

  # Resolve file path(s) — handle glob patterns
  if [[ "$FILE_PATTERN" == *"*"* ]]; then
    # Glob pattern — find matching files
    MATCHING_FILES=$(find "$PROJECT_ROOT" -path "$PROJECT_ROOT/$FILE_PATTERN" -type f 2>/dev/null | head -10)
  else
    # Direct path
    MATCHING_FILES="$PROJECT_ROOT/$FILE_PATTERN"
  fi

  while IFS= read -r CONFIG_FILE; do
    [[ -z "$CONFIG_FILE" ]] && continue
    [[ ! -f "$CONFIG_FILE" ]] && continue

    # Convert PCRE syntax to ERE for portability
    # \s → [[:space:]], (?:...) → (...), remove (?!...) negative lookahead (can't do in ERE)
    PATTERN=$(printf "%s" "$PATTERN" | sed 's/\\s/[[:space:]]/g; s/(?:/(/g; s/(?![^)]*)//')

    # Search for the attack pattern in the file
    if grep -qE "$PATTERN" "$CONFIG_FILE" 2>/dev/null; then
      FINDING_COUNT=$((FINDING_COUNT + 1))
      REL_PATH="${CONFIG_FILE#"$PROJECT_ROOT"/}"

      # ── Log to audit trail ──
      CVE_REF="${CVE:-none}"
      AUDIT_ENTRY=$(jq -cn \
        --arg event "config_attack_detected" \
        --arg ts "$TIMESTAMP" \
        --arg file "$REL_PATH" \
        --arg check "$CHECK_TYPE" \
        --arg cve "$CVE_REF" \
        --arg severity "$SEVERITY" \
        --arg description "$DESCRIPTION" \
        '{event:$event, ts:$ts, file:$file, check:$check, cve:$cve, severity:$severity, description:$description}')

      log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"

      # ── stderr output for Claude ──
      if [[ "$SEVERITY" == "critical" ]]; then
        printf "[Hydra] CRITICAL CONFIG: %s\n  File: %s\n  Attack: %s\n" "$DESCRIPTION" "$REL_PATH" "$CVE_REF" >&2
      elif [[ "$SEVERITY" == "high" ]]; then
        printf "[Hydra] CONFIG WARNING: %s\n  File: %s\n" "$DESCRIPTION" "$REL_PATH" >&2
      else
        printf "[Hydra] CONFIG NOTE: %s in %s\n" "$DESCRIPTION" "$REL_PATH" >&2
      fi
    fi
  done <<< "$MATCHING_FILES"
done < <(jq -r '.[] | [.file_pattern, .check, .pattern, (.cve // ""), .severity, .description] | join("\t")' "$PATTERNS_FILE" 2>/dev/null)

# ── Summary ──
if [[ $FINDING_COUNT -gt 0 ]]; then
  printf "[Hydra] Config shield found %d suspicious config(s). Run /hydra:config-check for details.\n" "$FINDING_COUNT" >&2

  SUMMARY=$(jq -cn \
    --arg event "config_scan_complete" \
    --arg ts "$TIMESTAMP" \
    --arg project "$PROJECT_ROOT" \
    --argjson count "$FINDING_COUNT" \
    '{event:$event, ts:$ts, project:$project, findings:$count}')

  log_metric "${STATE_DIR}/metrics.jsonl" "$SUMMARY"
fi

exit 0
