#!/usr/bin/env bash
# Verify shared/conduct/ in this repo matches agent-foundations/conduct/ canonical.
# Usage: conduct-abi-check.sh <path-to-canonical>
set -euo pipefail
CANONICAL="${1:-../agent-foundations/conduct}"
LOCAL="shared/conduct"
DRIFT=0
[ -d "$LOCAL" ] || { echo "no shared/conduct here"; exit 0; }
for f in "$CANONICAL"/*.md; do
  base=$(basename "$f")
  if [ ! -f "$LOCAL/$base" ]; then echo "MISSING: $LOCAL/$base"; DRIFT=1; continue; fi
  diff -q "$f" "$LOCAL/$base" >/dev/null 2>&1 || { echo "DRIFT: $base"; DRIFT=1; }
done
exit $DRIFT
