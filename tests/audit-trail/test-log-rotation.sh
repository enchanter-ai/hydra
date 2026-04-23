#!/usr/bin/env bash
# Test: audit-trail rotates audit.jsonl at 10MB
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source metrics.sh to test rotation directly
source "$HYDRA_ROOT/shared/constants.sh"
source "$HYDRA_ROOT/shared/metrics.sh"

# Create temp state dir with large audit file
TMPDIR=$(mktemp -d /tmp/hydra-test-rotation-XXXXXX)
AUDIT_FILE="$TMPDIR/audit.jsonl"

# Create a file larger than 10MB
# Each line is ~60 bytes, so we need ~175000 lines for 10.5MB
LINE='{"event":"test","ts":"2026-01-01T00:00:00Z","tool":"test_rotation"}'
for i in $(seq 1 180000); do
  printf "%s\n" "$LINE"
done > "$AUDIT_FILE"

SIZE_BEFORE=$(wc -c < "$AUDIT_FILE" | tr -d ' ')

# Verify file is actually > 10MB before testing rotation
if [[ "$SIZE_BEFORE" -lt 10485760 ]]; then
  rm -rf "$TMPDIR"
  echo "FAIL: test setup error — file only $SIZE_BEFORE bytes, need >10MB"
  exit 1
fi

# Log one more metric — this should trigger rotation
log_metric "$AUDIT_FILE" '{"event":"trigger_rotation","ts":"2026-01-01T00:00:01Z"}'

SIZE_AFTER=$(wc -c < "$AUDIT_FILE" | tr -d ' ')

rm -rf "$TMPDIR"

# After rotation, file should be smaller (kept last 1000 lines)
if [[ "$SIZE_AFTER" -ge "$SIZE_BEFORE" ]]; then
  echo "FAIL: file was not rotated (before: $SIZE_BEFORE, after: $SIZE_AFTER)"
  exit 1
fi

exit 0
