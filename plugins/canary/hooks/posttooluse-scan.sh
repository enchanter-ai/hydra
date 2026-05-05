#!/usr/bin/env bash
# canary: PostToolUse(*) hook — scans every tool's input + output for
# leakage of any active canary token from state/active-canaries.json.
#
# A hit means an attacker-controlled string carrying the canary token
# made it back through the agent into a subsequent tool call — the
# canonical signature of a successful indirect prompt injection.
#
# Advisory contract per shared/conduct/hooks.md — never block, never exit non-zero.

# Subagent recursion guard — see shared/conduct/hooks.md.
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

# Fail-open: never propagate errors out of an advisory hook.
trap 'exit 0' ERR INT TERM
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Cheap pre-filter: only scan when at least one canary is active. If the
# state file is absent or empty, no PreToolUse(WebFetch) has fired this
# session and nothing can leak — skip without spinning up python.
STATE_FILE="${PLUGIN_ROOT}/state/active-canaries.json"
if [[ ! -s "$STATE_FILE" ]]; then exit 0; fi

# Dependencies — silently skip if missing.
PY=python3
if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY=python
  else
    exit 0
  fi
fi

# Forward the full hook payload (stdin) to the scanner. The scanner reads
# tool_input + tool_response, greps for any active canary, emits a stderr
# advisory on hit, and appends a finding to state/hits.ndjson via locked append.
HOOK_INPUT=$(head -c 1048576)
printf "%s" "$HOOK_INPUT" | "$PY" "${PLUGIN_ROOT}/scripts/canary-scan.py" || true

# ALWAYS exit 0. Advisory contract.
exit 0
