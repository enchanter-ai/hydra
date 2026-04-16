#!/usr/bin/env bash
# Reaper cross-platform compatibility layer
# Provides portable wrappers for GNU vs BSD tool differences.
# Must be sourced, not executed.

# ── Hash functions ──

reaper_md5() {
  # Returns first 8 chars of MD5 hash of input string
  local input="$1"
  if command -v md5sum >/dev/null 2>&1; then
    printf "%s" "$input" | md5sum 2>/dev/null | cut -c1-8
  elif command -v md5 >/dev/null 2>&1; then
    printf "%s" "$input" | md5 2>/dev/null | cut -c1-8
  else
    # Fallback: use cksum (POSIX, available everywhere)
    printf "%s" "$input" | cksum 2>/dev/null | cut -d' ' -f1
  fi
}

reaper_md5_file() {
  # Returns first 8 chars of MD5 hash of a file
  local filepath="$1"
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$filepath" 2>/dev/null | cut -c1-8
  elif command -v md5 >/dev/null 2>&1; then
    md5 -q "$filepath" 2>/dev/null | cut -c1-8
  else
    cksum "$filepath" 2>/dev/null | cut -d' ' -f1
  fi
}

reaper_sha256_file() {
  # Returns first 16 chars of SHA256 hash of a file
  local filepath="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$filepath" 2>/dev/null | cut -c1-16
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$filepath" 2>/dev/null | cut -c1-16
  else
    # Fallback: use cksum
    cksum "$filepath" 2>/dev/null | cut -d' ' -f1
  fi
}

# ── Binary file detection ──

reaper_is_binary() {
  # Returns 0 (true) if file appears to be binary
  local filepath="$1"
  if command -v file >/dev/null 2>&1; then
    local mime
    mime=$(file -b --mime-type "$filepath" 2>/dev/null || true)
    case "$mime" in
      text/*|application/json|application/xml|application/javascript)
        return 1 ;;  # Not binary
      "")
        return 1 ;;  # Unknown, treat as text
      *)
        return 0 ;;  # Binary
    esac
  else
    # Heuristic: check for null bytes in first 512 bytes
    if head -c 512 "$filepath" 2>/dev/null | grep -qP '\x00' 2>/dev/null; then
      return 0  # Binary
    fi
    return 1  # Text
  fi
}

# ── File size (portable) ──

reaper_file_size() {
  # Returns file size in bytes
  local filepath="$1"
  if stat --version >/dev/null 2>&1; then
    # GNU stat
    stat -c %s "$filepath" 2>/dev/null
  else
    # BSD stat
    stat -f %z "$filepath" 2>/dev/null
  fi
}

# ── Stdin reading with size cap ──

reaper_read_stdin() {
  # Read stdin with a size limit (default 1MB)
  local max_bytes="${1:-1048576}"
  head -c "$max_bytes" 2>/dev/null
}

# ── Stale lock cleanup ──

reaper_acquire_lock() {
  # Same as acquire_lock but cleans stale locks older than 60s
  local lock_dir="$1"
  local retries=50

  # Check for stale lock (older than 60 seconds)
  if [[ -d "$lock_dir" ]]; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_dir" 2>/dev/null || stat -f %m "$lock_dir" 2>/dev/null || echo "0") ))
    if [[ "$lock_age" -gt 60 ]]; then
      rmdir "$lock_dir" 2>/dev/null || true
    fi
  fi

  while ! mkdir "$lock_dir" 2>/dev/null; do
    ((retries--))
    [[ $retries -le 0 ]] && return 1
    sleep 0.1
  done
  return 0
}
