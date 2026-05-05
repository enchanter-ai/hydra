#!/usr/bin/env python3
"""
egress-monitor: append-only logger of network destinations.

Reads a Claude Code PostToolUse hook payload from stdin, extracts the network
destination (host) when applicable, appends one NDJSON record to
state/log.ndjson, and prints a stderr advisory the first time a host is seen.

Tools handled:
  WebFetch  → tool_input.url            → host
  WebSearch → log just "websearch" with query length (no query content)
  Bash      → parse argv for curl/wget URLs, or git remote name for
              push/pull/clone/fetch (URL itself NOT logged for git)

Always exits 0. The hook wrapper (posttooluse.sh) is the contract surface;
this script is observe-and-record.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

SCRIPT_DIR = Path(__file__).resolve().parent
STATE_DIR = SCRIPT_DIR.parent / "state"
LOG_PATH = STATE_DIR / "log.ndjson"
SEEN_PATH = STATE_DIR / "seen-domains.json"

ADVISORY_HEADER = "=== egress-monitor (advisory) ==="


# ── append_jsonl_locked — per templates.md § G ─────────────────────────────
def append_jsonl_locked(path: Path, line: str) -> None:
    """Append one JSON line, locked + flushed. Cross-platform."""
    path.parent.mkdir(parents=True, exist_ok=True)
    if not line.endswith("\n"):
        line += "\n"
    with path.open("a", encoding="utf-8") as f:
        if sys.platform == "win32":
            import msvcrt
            try:
                msvcrt.locking(f.fileno(), msvcrt.LK_LOCK, 1)
                f.write(line)
                f.flush()
                os.fsync(f.fileno())
            finally:
                try:
                    f.seek(0)
                    msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
                except OSError:
                    pass
        else:
            import fcntl
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX)
                f.write(line)
                f.flush()
                os.fsync(f.fileno())
            finally:
                fcntl.flock(f.fileno(), fcntl.LOCK_UN)


# ── seen-domains atomic read/write ─────────────────────────────────────────
def read_seen() -> set[str]:
    try:
        with SEEN_PATH.open("r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict) and isinstance(data.get("hosts"), list):
            return {str(h) for h in data["hosts"]}
        if isinstance(data, list):
            return {str(h) for h in data}
    except (OSError, json.JSONDecodeError):
        pass
    return set()


def write_seen(hosts: set[str]) -> None:
    """Atomic write: temp file in same dir, then os.replace."""
    try:
        SEEN_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = SEEN_PATH.with_suffix(f".json.{os.getpid()}.tmp")
        payload = {"hosts": sorted(hosts)}
        with tmp.open("w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2)
        os.replace(tmp, SEEN_PATH)
    except OSError:
        pass  # seen-set update failure is never fatal


# ── URL / argv parsing ─────────────────────────────────────────────────────
_URL_RE = re.compile(r"https?://[^\s'\"<>|;&)]+", re.IGNORECASE)


def host_of(url: str) -> str | None:
    try:
        p = urlparse(url)
        h = (p.hostname or "").lower().strip()
        return h or None
    except ValueError:
        return None


def extract_bash_targets(command: str) -> list[tuple[str, str]]:
    """Return list of (kind, value).
       kind ∈ {'host', 'git-remote'}.
       value is a host for curl/wget/http URL hits; remote name for git ops.
    """
    out: list[tuple[str, str]] = []
    cmd_l = command.lower()

    # Git network ops: log only the remote name, never the URL.
    git_match = re.search(r"\bgit\s+(push|pull|clone|fetch)(?:\s+(\S+))?", command)
    if git_match:
        remote = git_match.group(2) or "(default)"
        # If the second token starts with a flag, fall back to default.
        if remote.startswith("-"):
            remote = "(default)"
        # If clone/push/pull was given a full URL, redact it: log "(url-redacted)".
        if remote.startswith(("http://", "https://", "git@", "ssh://", "git://")):
            remote = "(url-redacted)"
        out.append(("git-remote", remote))
        return out

    # curl / wget / generic http URL → extract URLs from argv.
    if "curl" in cmd_l or "wget" in cmd_l or "http" in cmd_l:
        seen_local: set[str] = set()
        # First try a clean shlex split so we ignore URLs inside quoted bodies
        # only when it's well-formed; fall back to regex over the raw string.
        try:
            tokens = shlex.split(command, posix=True)
        except ValueError:
            tokens = []
        candidates: list[str] = []
        for tok in tokens:
            for m in _URL_RE.findall(tok):
                candidates.append(m)
        if not candidates:
            for m in _URL_RE.findall(command):
                candidates.append(m)
        for url in candidates:
            h = host_of(url)
            if h and h not in seen_local:
                seen_local.add(h)
                out.append(("host", h))

    return out


# ── main ───────────────────────────────────────────────────────────────────
def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def emit_first_seen_advisory(host: str) -> None:
    sys.stderr.write(ADVISORY_HEADER + "\n")
    sys.stderr.write(f"First-seen destination: {host}\n")
    # Path is informational; keep relative so it is not machine-specific.
    sys.stderr.write("Review: state/log.ndjson\n")


def log_record(record: dict) -> None:
    append_jsonl_locked(LOG_PATH, json.dumps(record, separators=(",", ":")))


def handle(payload: dict) -> int:
    tool = str(payload.get("tool_name") or "")
    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}

    seen = read_seen()
    new_hosts: list[str] = []

    if tool == "WebFetch":
        url = str(tool_input.get("url") or "")
        h = host_of(url) if url else None
        if h:
            first_seen = h not in seen
            log_record({
                "ts": now_iso(),
                "tool": "WebFetch",
                "host": h,
                "first_seen": first_seen,
            })
            if first_seen:
                emit_first_seen_advisory(h)
                new_hosts.append(h)

    elif tool == "WebSearch":
        # Privacy: do not log query content; only its length.
        query = str(tool_input.get("query") or "")
        log_record({
            "ts": now_iso(),
            "tool": "WebSearch",
            "host": "websearch",
            "query_len": len(query),
            "first_seen": False,
        })
        # "websearch" is a synthetic destination; never advisory-warn on it.

    elif tool == "Bash":
        command = str(tool_input.get("command") or "")
        if not command:
            return 0
        targets = extract_bash_targets(command)
        for kind, value in targets:
            if kind == "host":
                first_seen = value not in seen and value not in new_hosts
                log_record({
                    "ts": now_iso(),
                    "tool": "Bash",
                    "host": value,
                    "first_seen": first_seen,
                })
                if first_seen:
                    emit_first_seen_advisory(value)
                    new_hosts.append(value)
            elif kind == "git-remote":
                # Git remotes are not internet hosts; log distinctly and never
                # advisory-warn (URL is not exposed).
                log_record({
                    "ts": now_iso(),
                    "tool": "Bash",
                    "host": f"git:{value}",
                    "first_seen": False,
                })
    else:
        return 0  # other tools — should already be filtered by hook matcher

    if new_hosts:
        seen.update(new_hosts)
        write_seen(seen)

    return 0


def main() -> int:
    raw = sys.stdin.read(262144) if not sys.stdin.isatty() else ""
    if not raw:
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0
    if not isinstance(payload, dict):
        return 0
    return handle(payload)


if __name__ == "__main__":
    # Even an unhandled exception must not propagate — the hook wrapper also
    # forces exit 0, but defense-in-depth.
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
