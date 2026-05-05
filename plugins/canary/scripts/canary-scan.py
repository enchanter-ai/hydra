#!/usr/bin/env python3
"""
canary-scan: PostToolUse(*) scanner.

Reads the hook payload from stdin, loads active canary tokens from
state/active-canaries.json, and greps the tool's input + output for any
token. On hit, emits a stderr advisory and appends a finding to
state/hits.ndjson via a locked, fsynced append (cross-platform — see
templates.md spec G).

A hit means attacker-controlled text carrying the canary made it back
through the agent into a subsequent tool call — the canonical signature
of a successful indirect prompt injection.

Always exits 0 — caller is the hook contract surface.
"""

from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
STATE_FILE = PLUGIN_ROOT / "state" / "active-canaries.json"
HITS_FILE = PLUGIN_ROOT / "state" / "hits.ndjson"


def append_jsonl_locked(path: Path, line: str) -> None:
    """Append one JSON line, locked + flushed. Cross-platform.

    Implementation copied verbatim from templates.md § G so future
    automated drift-checks against the spec match.
    """
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


def _load_active_tokens() -> list[str]:
    if not STATE_FILE.exists():
        return []
    try:
        with STATE_FILE.open("r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return []
    sessions = data.get("sessions", {}) if isinstance(data, dict) else {}
    tokens: list[str] = []
    for entry in sessions.values():
        if isinstance(entry, dict):
            t = entry.get("token")
            if isinstance(t, str) and t.startswith("CANARY-"):
                tokens.append(t)
    return tokens


def _stringify(obj) -> str:
    if obj is None:
        return ""
    if isinstance(obj, str):
        return obj
    try:
        return json.dumps(obj, ensure_ascii=False)
    except Exception:
        return str(obj)


def main() -> int:
    tokens = _load_active_tokens()
    if not tokens:
        return 0

    raw = sys.stdin.read()
    if not raw:
        return 0
    try:
        payload = json.loads(raw)
    except Exception:
        return 0

    tool_name = payload.get("tool_name") or payload.get("tool") or "unknown"
    tool_input = _stringify(payload.get("tool_input"))
    tool_response = _stringify(
        payload.get("tool_response") or payload.get("tool_output")
    )
    haystack = tool_input + "\n" + tool_response

    for token in tokens:
        if token in haystack:
            where = "input" if token in tool_input else "output"
            ts = int(time.time())
            sys.stderr.write(
                "=== canary (advisory) ===\n"
                f"HIT: canary {token} appeared in {tool_name} {where}. "
                "Prompt injection likely. Review session and rotate.\n"
            )
            sys.stderr.flush()
            try:
                finding = {
                    "ts": ts,
                    "token": token,
                    "tool": tool_name,
                    "where": where,
                    "session_id": payload.get("session_id"),
                }
                append_jsonl_locked(HITS_FILE, json.dumps(finding, ensure_ascii=False))
            except Exception:
                # Never propagate I/O failure out of an advisory hook.
                pass
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
