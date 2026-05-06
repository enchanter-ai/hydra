#!/usr/bin/env bash
# conduct-sync.sh — propagate canonical conduct modules to consumer repos.
# Usage: conduct-sync.sh <consumer-repo-path>
# Run from agent-foundations root; copies agent-foundations/conduct/*.md
# into <consumer>/shared/conduct/, preserving CONDUCT_SOURCE.md.
set -euo pipefail
CANONICAL_DIR="$(cd "$(dirname "$0")/.." && pwd)/conduct"
CONSUMER="${1:?usage: conduct-sync.sh <consumer-repo-path>}"
TARGET="$CONSUMER/shared/conduct"
[ -d "$TARGET" ] || { echo "ERR: $TARGET not a directory"; exit 2; }
COPIED=0; SKIPPED=0
for f in "$CANONICAL_DIR"/*.md; do
  base=$(basename "$f")
  # CONDUCT_SOURCE.md is consumer-specific marker; never overwrite
  [ "$base" = "CONDUCT_SOURCE.md" ] && { SKIPPED=$((SKIPPED+1)); continue; }
  if [ ! -f "$TARGET/$base" ] || ! diff -q "$f" "$TARGET/$base" >/dev/null 2>&1; then
    cp "$f" "$TARGET/$base"
    COPIED=$((COPIED+1))
  else
    SKIPPED=$((SKIPPED+1))
  fi
done
echo "$CONSUMER: copied=$COPIED skipped=$SKIPPED"
