#!/usr/bin/env bash
# audit-trail: PostToolUse hook
# Central security event logger. Fires on ALL tool calls.
# Logs every tool use to audit.jsonl for compliance and review.
# Lightweight — no heavy processing, just structured logging.
# MUST exit 0 always.

trap 'exit 0' ERR INT TERM

set -uo pipefail

# ── Check dependencies ──
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

# Resolve paths
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
SHARED_DIR="${PLUGIN_ROOT}/../../shared"

# shellcheck source=../../../../shared/constants.sh
source "${SHARED_DIR}/constants.sh"
# shellcheck source=../../../../shared/metrics.sh
source "${SHARED_DIR}/metrics.sh"
# shellcheck source=../../../../shared/compat.sh
source "${SHARED_DIR}/compat.sh"

# ── Read hook input from stdin (capped at 1MB) ──
HOOK_INPUT=$(hydra_read_stdin 1048576)

if [[ -z "$HOOK_INPUT" ]]; then exit 0; fi

# Validate JSON
if ! printf "%s" "$HOOK_INPUT" | jq empty >/dev/null 2>&1; then
  exit 0
fi

# Extract fields in a single jq call
PARSED=$(printf "%s" "$HOOK_INPUT" | jq -r '[
  .tool_name // "",
  .tool_input.file_path // .tool_input.command // "",
  .tool_input.pattern // "",
  .transcript_path // ""
] | join("\t")' 2>/dev/null)

TOOL_NAME=$(printf "%s" "$PARSED" | cut -f1)
TARGET=$(printf "%s" "$PARSED" | cut -f2)
PATTERN=$(printf "%s" "$PARSED" | cut -f3)

if [[ -z "$TOOL_NAME" ]]; then exit 0; fi

# ── Build audit entry ──
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
STATE_DIR="${PLUGIN_ROOT}/state"

# Sanitize target to avoid logging secrets
SAFE_TARGET=""
if [[ -n "$TARGET" ]]; then
  # For Bash commands, truncate and sanitize
  if [[ "$TOOL_NAME" == "Bash" ]]; then
    SAFE_TARGET=$(printf "%s" "$TARGET" | head -c 200 | sed -E \
      -e 's/(password|secret|token|api.key)=[^ ]*/\1=[REDACTED]/gi' \
      -e 's/(sk-[a-zA-Z0-9]{4})[a-zA-Z0-9]+/\1[...]/g')
  else
    SAFE_TARGET="$TARGET"
  fi
fi

AUDIT_ENTRY=$(jq -cn \
  --arg event "tool_use" \
  --arg ts "$TIMESTAMP" \
  --arg tool "$TOOL_NAME" \
  --arg target "$SAFE_TARGET" \
  '{event:$event, ts:$ts, tool:$tool, target:$target}')

log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"

# ── Log to metrics (lightweight counter) ──
METRIC=$(jq -cn \
  --arg event "tool_logged" \
  --arg ts "$TIMESTAMP" \
  --arg tool "$TOOL_NAME" \
  '{event:$event, ts:$ts, tool:$tool}')

log_metric "${STATE_DIR}/metrics.jsonl" "$METRIC"

exit 0
