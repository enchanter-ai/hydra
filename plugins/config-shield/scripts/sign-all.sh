#!/usr/bin/env bash
# config-shield: sign every .claude/settings*.json and */hooks/hooks.json under
# the current working directory (or the path passed as $1).
#
# Operator workflow: run after every config change so the SessionStart verify
# step has a fresh baseline to compare against.
#
# Usage:
#   bash sign-all.sh           # search cwd
#   bash sign-all.sh <root>    # search <root>

set -uo pipefail

ROOT="${1:-$(pwd)}"

if [[ ! -d "$ROOT" ]]; then
  echo "sign-all: not a directory: $ROOT" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGN="$SCRIPT_DIR/sign-config.sh"

if [[ ! -x "$SIGN" ]] && ! bash -n "$SIGN" 2>/dev/null; then
  echo "sign-all: sign-config.sh missing or unreadable: $SIGN" >&2
  exit 1
fi

COUNT=0

# settings.json + settings.local.json under any .claude/
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  bash "$SIGN" "$f" && COUNT=$((COUNT + 1))
done < <(find "$ROOT" -type f \( -path '*/.claude/settings.json' -o -path '*/.claude/settings.local.json' \) 2>/dev/null)

# hooks.json under any hooks/ dir (plugin or project-level)
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  bash "$SIGN" "$f" && COUNT=$((COUNT + 1))
done < <(find "$ROOT" -type f -path '*/hooks/hooks.json' 2>/dev/null)

echo "sign-all: signed $COUNT config file(s) under $ROOT"
exit 0
