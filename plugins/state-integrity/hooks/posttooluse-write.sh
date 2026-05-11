#!/usr/bin/env bash
# state-integrity: PostToolUse hook
# Fires on Write/Edit/MultiEdit. Runs the meta-canary scanner to compare current
# HMACs of every watched defense-state file against the signed baseline.
# Drift OR missing file triggers a HIGH-severity event written to
# state/integrity-events.ndjson via locked append.
#
# Advisory contract: ALWAYS exit 0 (per shared/conduct/hooks.md).

# Subagent recursion guard
if [[ -n "${CLAUDE_SUBAGENT:-}" ]]; then exit 0; fi

trap 'exit 0' ERR INT TERM
set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Skip if python or openssl missing — fail open, never block.
if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  exit 0
fi
if ! command -v openssl >/dev/null 2>&1; then
  exit 0
fi

PY="python3"
command -v python3 >/dev/null 2>&1 || PY="python"

# Best-effort: run the scanner. Never propagate its exit code.
"$PY" "${PLUGIN_ROOT}/scripts/scan-defense-state.py" \
  --plugin-root "${PLUGIN_ROOT}" \
  --reason "posttooluse-write" \
  >/dev/null 2>&1 || true

exit 0
