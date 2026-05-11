#!/usr/bin/env bash
# config-shield: SessionStart signature verification.
#
# For each .claude/settings*.json and hooks/hooks.json reachable from the
# session cwd (and its ancestor chain), run verify-config.sh:
#   exit 0 → signature matches, silent
#   exit 1 → signature MISMATCH, emit advisory; under fail_on_signature_mismatch
#           policy exit 2 (blocks session start)
#   exit 2 → signature absent, emit info-level advisory only
#
# Advisory by default — exit 0 unless policy says otherwise.
# Closes R-019: settings.json + hooks.json now signed + verified.

# Subagent recursion guard
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

trap 'exit 0' INT TERM
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then exit 0; fi
if ! command -v openssl >/dev/null 2>&1; then exit 0; fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
VERIFY="${PLUGIN_ROOT}/scripts/verify-config.sh"

if [[ ! -f "$VERIFY" ]]; then exit 0; fi

# ── Determine project root from hook stdin ──
HOOK_INPUT=$(head -c 1048576 2>/dev/null)

PROJECT_ROOT=""
if [[ -n "$HOOK_INPUT" ]]; then
  PROJECT_ROOT=$(printf "%s" "$HOOK_INPUT" | jq -r '.cwd // ""' 2>/dev/null)
fi
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
[[ ! -d "$PROJECT_ROOT" ]] && exit 0

# ── Load policy ──
POLICY_FILE="${PLUGIN_ROOT}/state/config-shield-policy.json"
VERIFY_AT_START=true
FAIL_ON_MISMATCH=false
if [[ -f "$POLICY_FILE" ]]; then
  VAL=$(jq -r '.verify_at_session_start // true' "$POLICY_FILE" 2>/dev/null)
  [[ "$VAL" == "false" ]] && VERIFY_AT_START=false
  VAL=$(jq -r '.fail_on_signature_mismatch // false' "$POLICY_FILE" 2>/dev/null)
  [[ "$VAL" == "true" ]] && FAIL_ON_MISMATCH=true
fi

[[ "$VERIFY_AT_START" == "false" ]] && exit 0

# ── Collect candidate config files (project + ancestor chain) ──
collect_configs() {
  local dir="$1"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    [[ -f "$dir/.claude/settings.json" ]]       && printf "%s\n" "$dir/.claude/settings.json"
    [[ -f "$dir/.claude/settings.local.json" ]] && printf "%s\n" "$dir/.claude/settings.local.json"
    dir="$(dirname "$dir")"
    [[ "$dir" == "." || "$dir" == "/" ]] && break
  done
  # plugin hooks.json files under the project
  find "$1" -type f -path '*/hooks/hooks.json' 2>/dev/null
}

MISMATCH_COUNT=0
MISSING_COUNT=0

while IFS= read -r cfg; do
  [[ -z "$cfg" ]] && continue
  bash "$VERIFY" "$cfg"
  rc=$?
  case "$rc" in
    0) ;;  # match
    1)
      MISMATCH_COUNT=$((MISMATCH_COUNT + 1))
      printf "=== config-shield (ADVISORY) === SIGNATURE MISMATCH: %s — config may have been tampered. Re-verify against signed baseline.\n" "$cfg" >&2
      ;;
    2)
      MISSING_COUNT=$((MISSING_COUNT + 1))
      printf "=== config-shield (info) === unsigned config: %s — run: bash plugins/config-shield/scripts/sign-config.sh %s\n" "$cfg" "$cfg" >&2
      ;;
  esac
done < <(collect_configs "$PROJECT_ROOT" | sort -u)

# ── Blocking path (opt-in via policy) ──
if [[ "$FAIL_ON_MISMATCH" == "true" && $MISMATCH_COUNT -gt 0 ]]; then
  printf "=== config-shield === Session start BLOCKED by policy: %d signature mismatch(es). Inspect, then re-sign with sign-all.sh.\n" "$MISMATCH_COUNT" >&2
  exit 2
fi

exit 0
