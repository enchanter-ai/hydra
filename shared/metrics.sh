#!/usr/bin/env bash
# Reaper shared metrics — JSONL append with atomic mkdir locks + 10MB rotation

# Source constants if not already loaded
if [[ -z "${REAPER_LOCK_SUFFIX:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=constants.sh
  source "${SCRIPT_DIR}/constants.sh"
fi

acquire_lock() {
  local lock_dir="$1"
  local retries=50
  while ! mkdir "${lock_dir}" 2>/dev/null; do
    ((retries--))
    [[ $retries -le 0 ]] && return 1
    sleep 0.1
  done
  return 0
}

release_lock() {
  rmdir "$1" 2>/dev/null || true
}

log_metric() {
  local file="${1:-state/metrics.jsonl}"
  local payload="$2"
  local lock_dir="${file}${REAPER_LOCK_SUFFIX}"
  local max_size="${REAPER_MAX_METRICS_BYTES:-10485760}"

  # Validate JSON before writing
  if ! printf "%s" "$payload" | jq empty >/dev/null 2>&1; then
    return 0
  fi

  # Acquire lock (atomic mkdir, never flock)
  acquire_lock "$lock_dir" || return 0

  # Rotate at 10MB
  if [[ -f "$file" ]]; then
    local size
    size=$(wc -c < "$file" | tr -d ' ')
    if [[ "$size" -gt "$max_size" ]]; then
      tail -n 1000 "$file" > "${file}.tmp"
      mv "${file}.tmp" "$file"
    fi
  fi

  mkdir -p "$(dirname "$file")"
  printf "%s\n" "$payload" >> "$file"

  release_lock "$lock_dir"
  return 0
}
