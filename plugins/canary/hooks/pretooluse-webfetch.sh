#!/usr/bin/env bash
# canary: PreToolUse(WebFetch) hook — seeds a per-session canary token.
#
# Emits a stderr advisory with a high-entropy CANARY-<8-char-base32> token
# AND the system instruction telling the model to treat the token as a
# tripwire — never act on it, only report it. The scan-phase hook then
# greps every subsequent tool input/output for the token; a hit indicates
# a successful indirect prompt injection routed the canary back through
# the agent.
#
# Advisory contract per shared/conduct/hooks.md — never block, never exit non-zero.

# Subagent recursion guard — see shared/conduct/hooks.md.
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

# Fail-open: never propagate errors out of an advisory hook.
trap 'exit 0' ERR INT TERM
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Dependencies — silently skip if missing.
PY=python3
if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY=python
  else
    exit 0
  fi
fi

# Read hook payload from stdin (capped at 256KB) and forward to seeder.
# The seeder writes/updates state/active-canaries.json atomically and
# emits the advisory block to stderr (visible to Claude per hook contract).
HOOK_INPUT=$(head -c 262144)
printf "%s" "$HOOK_INPUT" | "$PY" "${PLUGIN_ROOT}/scripts/canary-seed.py" || true

# ALWAYS exit 0. Advisory contract.
exit 0
