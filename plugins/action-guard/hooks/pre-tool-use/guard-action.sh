#!/usr/bin/env bash
# action-guard: PreToolUse hook
# Implements R4 (Markov Action Classification) and R7 (Subcommand Overflow Detection).
# Classifies Bash commands as SAFE/RISKY/DANGEROUS.
# Advisory contract per shared/conduct/hooks.md — never block, never exit non-zero.
# Emits a stderr advisory ("Would have blocked: ...") and lets the tool proceed.
# Fires on Bash tool calls before execution.


# Subagent recursion guard — see shared/conduct/hooks.md
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

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
# shellcheck source=../../../../shared/compat.sh
source "${SHARED_DIR}/compat.sh"

# ── Read hook input from stdin (capped at 1MB) ──
HOOK_INPUT=$(hydra_read_stdin 1048576)

if ! validate_json "$HOOK_INPUT"; then
  exit 0
fi

# Extract command from tool_input
COMMAND=$(printf "%s" "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# ── Read strictness mode ──
STATE_DIR="${PLUGIN_ROOT}/state"
MODE="$HYDRA_DEFAULT_MODE"
CONFIG_FILE="${STATE_DIR}/config.json"
if [[ -f "$CONFIG_FILE" ]] && jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
  CONFIGURED_MODE=$(jq -r '.mode // ""' "$CONFIG_FILE" 2>/dev/null)
  case "$CONFIGURED_MODE" in
    strict|balanced|permissive) MODE="$CONFIGURED_MODE" ;;
  esac
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ── R7: Subcommand Overflow Detection ──
# Count subcommands split by ;, &&, ||, |
# The Adversa AI bypass used 50+ subcommands to overwhelm deny rules
# Count separators safely — grep/pipefail issues require careful handling
SUBCOMMAND_COUNT=1
PIPE_COUNT=1
AND_COUNT=0
if printf "%s" "$COMMAND" | grep -q ';' 2>/dev/null; then
  SUBCOMMAND_COUNT=$(printf "%s" "$COMMAND" | tr -cd ';' | wc -c | tr -d '[:space:]')
  SUBCOMMAND_COUNT=$((SUBCOMMAND_COUNT + 1))
fi
if printf "%s" "$COMMAND" | grep -q '|' 2>/dev/null; then
  PIPE_COUNT=$(printf "%s" "$COMMAND" | tr -cd '|' | wc -c | tr -d '[:space:]')
  PIPE_COUNT=$((PIPE_COUNT + 1))
fi
if printf "%s" "$COMMAND" | grep -q '&&' 2>/dev/null; then
  AND_COUNT=$(printf "%s" "$COMMAND" | sed 's/&&/\n/g' | wc -l | tr -d '[:space:]')
  AND_COUNT=$((AND_COUNT - 1))
fi

TOTAL_PARTS=$(( SUBCOMMAND_COUNT + PIPE_COUNT + AND_COUNT ))

if [[ "$TOTAL_PARTS" -gt "$HYDRA_SUBCOMMAND_LIMIT" ]]; then
  # Block: subcommand overflow
  AUDIT_ENTRY=$(jq -cn \
    --arg event "action_blocked" \
    --arg ts "$TIMESTAMP" \
    --arg reason "subcommand_overflow" \
    --argjson count "$TOTAL_PARTS" \
    --argjson limit "$HYDRA_SUBCOMMAND_LIMIT" \
    --arg mode "$MODE" \
    '{event:$event, ts:$ts, reason:$reason, subcommand_count:$count, limit:$limit, mode:$mode}')

  log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"

  {
    echo "=== action-guard (advisory) ==="
    printf "Would have blocked: command has %d subcommands (limit: %d). Matches the Adversa AI deny-rule bypass pattern.\n" "$TOTAL_PARTS" "$HYDRA_SUBCOMMAND_LIMIT"
    echo "Hint: split the command into separate steps and re-run, or invoke the /hydra:safety skill to authorize the chain deliberately."
  } >&2

  # Advisory only — never block. See shared/conduct/hooks.md.
  trap - ERR INT TERM
  exit 0
fi

# ── R4: Markov Action Classification ──
# Match against dangerous-ops.json patterns
PATTERNS_FILE="${SHARED_DIR}/${HYDRA_PATTERNS_DANGEROUS}"
if [[ ! -f "$PATTERNS_FILE" ]]; then exit 0; fi

# Check each pattern
BLOCKED="false"
WARNED="false"
BLOCK_REASON=""
WARN_REASONS=""

while IFS=$'\t' read -r PATTERN OP_ID SEVERITY CATEGORY ACTION DESCRIPTION; do
  [[ -z "$PATTERN" ]] && continue

  # Convert PCRE \s to ERE [[:space:]] for portability
  PATTERN=$(printf "%s" "$PATTERN" | sed 's/\\s/[[:space:]]/g')

  if printf "%s" "$COMMAND" | grep -qE "$PATTERN" 2>/dev/null; then
    if [[ "$ACTION" == "block" ]]; then
      case "$MODE" in
        strict|balanced)
          BLOCKED="true"
          BLOCK_REASON="$DESCRIPTION"
          # Log blocked action
          AUDIT_ENTRY=$(jq -cn \
            --arg event "action_blocked" \
            --arg ts "$TIMESTAMP" \
            --arg op_id "$OP_ID" \
            --arg severity "$SEVERITY" \
            --arg category "$CATEGORY" \
            --arg description "$DESCRIPTION" \
            --arg mode "$MODE" \
            '{event:$event, ts:$ts, op_id:$op_id, severity:$severity, category:$category, description:$description, mode:$mode}')
          log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"
          ;;
        permissive)
          WARNED="true"
          WARN_REASONS="${WARN_REASONS}${DESCRIPTION}; "
          ;;
      esac
    elif [[ "$ACTION" == "warn" ]]; then
      case "$MODE" in
        strict)
          BLOCKED="true"
          BLOCK_REASON="$DESCRIPTION"
          AUDIT_ENTRY=$(jq -cn \
            --arg event "action_blocked" \
            --arg ts "$TIMESTAMP" \
            --arg op_id "$OP_ID" \
            --arg severity "$SEVERITY" \
            --arg category "$CATEGORY" \
            --arg description "$DESCRIPTION" \
            --arg mode "$MODE" \
            '{event:$event, ts:$ts, op_id:$op_id, severity:$severity, category:$category, description:$description, mode:$mode}')
          log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"
          ;;
        balanced|permissive)
          WARNED="true"
          WARN_REASONS="${WARN_REASONS}${DESCRIPTION}; "
          ;;
      esac
    fi
  fi
done < <(jq -r '.[] | [.pattern, .id, .severity, .category, .action, .description] | join("\t")' "$PATTERNS_FILE" 2>/dev/null)

# ── Handle block decision ──
if [[ "$BLOCKED" == "true" ]]; then
  {
    echo "=== action-guard (advisory) ==="
    printf "Would have blocked: %s (mode: %s)\n" "$BLOCK_REASON" "$MODE"
    echo "Hint: review the matched dangerous-ops pattern; if intentional, invoke /hydra:safety to authorize."
  } >&2

  # Advisory only — never block. See shared/conduct/hooks.md.
  trap - ERR INT TERM
  exit 0
fi

# ── Handle warn decision ──
if [[ "$WARNED" == "true" ]]; then
  AUDIT_ENTRY=$(jq -cn \
    --arg event "action_warned" \
    --arg ts "$TIMESTAMP" \
    --arg reasons "$WARN_REASONS" \
    --arg mode "$MODE" \
    '{event:$event, ts:$ts, reasons:$reasons, mode:$mode}')

  log_metric "${STATE_DIR}/audit.jsonl" "$AUDIT_ENTRY"
  log_metric "${STATE_DIR}/metrics.jsonl" "$AUDIT_ENTRY"

  printf "[Hydra] WARNING: %s(mode: %s)\n" "$WARN_REASONS" "$MODE" >&2
fi

exit 0
