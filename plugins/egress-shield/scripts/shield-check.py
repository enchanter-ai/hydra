#!/usr/bin/env python3
"""
egress-shield: OPT-IN BLOCKING egress allowlist enforcer.

Reads a Claude Code PreToolUse hook payload from stdin, extracts the
destination host (when applicable), checks it against the operator's
allowlist in state/egress-policy.json, and:

  - exits 2 (block)  → host not in allowlist + policy.enabled is true
  - exits 0 (allow)  → host in allowlist OR policy disabled OR
                       no host extractable OR malformed policy (fail-safe)

Tools handled (same shapes as egress-monitor):
  WebFetch  → tool_input.url            → host
  WebSearch → synthetic 'websearch' destination — only blocked if
              'websearch' is missing from the allowlist
  Bash      → curl/wget URLs in argv → host
              git push/pull/clone/fetch → 'git:<remote>' destination

Audit-trail:
  Every block emits a 'policy_blocked' NDJSON event to
  state/audit.ndjson (locked append, per templates.md spec G).
  Allow paths are NOT logged — egress-monitor (advisory sibling) owns
  full observability; this plugin records only its own enforcement
  actions.

Fail-safe contract:
  ANY exception (parse failure, missing field, malformed policy, IO
  error) results in exit 0 — never block. The operator must fix the
  config to re-enable enforcement. This matches the README claim that
  malformed policy is fail-safe (default-disabled effective behavior).
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
PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT") or SCRIPT_DIR.parent)
STATE_DIR = PLUGIN_ROOT / "state"
POLICY_PATH = STATE_DIR / "egress-policy.json"
AUDIT_PATH = STATE_DIR / "audit.ndjson"

BLOCK_HEADER = "=== egress-shield (BLOCKED) ==="


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


# ── policy load (fail-safe) ────────────────────────────────────────────────
def load_policy() -> dict:
    """Return policy dict. On any failure, return disabled stub (fail-safe)."""
    try:
        with POLICY_PATH.open("r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            return {"enabled": False, "allowlist": []}
        # Normalize the two known fields. Anything else is ignored.
        enabled = bool(data.get("enabled", False))
        allowlist = data.get("allowlist", [])
        if not isinstance(allowlist, list):
            allowlist = []
        return {
            "enabled": enabled,
            "allowlist": [str(h).lower().strip() for h in allowlist if str(h).strip()],
        }
    except (OSError, json.JSONDecodeError, ValueError):
        return {"enabled": False, "allowlist": []}


# ── URL / argv parsing (mirrors egress-monitor) ────────────────────────────
_URL_RE = re.compile(r"https?://[^\s'\"<>|;&)]+", re.IGNORECASE)


def host_of(url: str) -> str | None:
    try:
        p = urlparse(url)
        h = (p.hostname or "").lower().strip()
        return h or None
    except ValueError:
        return None


def extract_targets(tool: str, tool_input: dict) -> list[str]:
    """Return list of destination strings to check against the allowlist."""
    out: list[str] = []
    if tool == "WebFetch":
        url = str(tool_input.get("url") or "")
        h = host_of(url) if url else None
        if h:
            out.append(h)
        return out

    if tool == "WebSearch":
        # Synthetic destination; operator can allow 'websearch' explicitly.
        out.append("websearch")
        return out

    if tool == "Bash":
        command = str(tool_input.get("command") or "")
        if not command:
            return out
        # Git network ops: log/check 'git:<remote>'.
        git_match = re.search(r"\bgit\s+(push|pull|clone|fetch)(?:\s+(\S+))?", command)
        if git_match:
            remote = git_match.group(2) or "(default)"
            if remote.startswith("-"):
                remote = "(default)"
            if remote.startswith(("http://", "https://", "git@", "ssh://", "git://")):
                # If a full URL was passed, extract host where possible.
                u = remote
                if u.startswith(("http://", "https://")):
                    h = host_of(u)
                    if h:
                        out.append(h)
                        return out
                remote = "(url-redacted)"
            out.append(f"git:{remote}")
            return out

        # curl / wget / generic http URL extraction.
        cmd_l = command.lower()
        if "curl" in cmd_l or "wget" in cmd_l or "http" in cmd_l:
            try:
                tokens = shlex.split(command, posix=True)
            except ValueError:
                tokens = []
            seen_local: set[str] = set()
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
                    out.append(h)
    return out


# ── allowlist match ────────────────────────────────────────────────────────
def host_allowed(host: str, allowlist: list[str]) -> bool:
    """Allowlist match: exact or suffix-after-dot for explicit subdomains.
    Allowlist entry 'example.com' matches 'example.com' AND 'api.example.com';
    'git:origin' matches exactly; 'websearch' matches exactly.
    """
    h = host.lower().strip()
    for entry in allowlist:
        e = entry.lower().strip()
        if not e:
            continue
        if h == e:
            return True
        # Subdomain match only for plain hostnames (no 'git:' or 'websearch' prefix).
        if "." in e and not e.startswith("git:") and h.endswith("." + e):
            return True
    return False


# ── audit emit ─────────────────────────────────────────────────────────────
def now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def emit_block_audit(tool: str, host: str, allowlist: list[str]) -> None:
    record = {
        "ts": now_iso(),
        "event": "policy_blocked",
        "shield": "egress-shield",
        "tool": tool,
        "host": host,
        "allowlist_size": len(allowlist),
    }
    try:
        append_jsonl_locked(AUDIT_PATH, json.dumps(record, separators=(",", ":")))
    except OSError:
        # Audit write failure must not change the block decision.
        pass


def emit_block_stderr(tool: str, host: str) -> None:
    sys.stderr.write(BLOCK_HEADER + "\n")
    sys.stderr.write(f"Tool: {tool}\n")
    sys.stderr.write(f"Destination not in allowlist: {host}\n")
    sys.stderr.write("Add the host to state/egress-policy.json#allowlist or set enabled:false to disable the shield.\n")


# ── main ───────────────────────────────────────────────────────────────────
def handle(payload: dict) -> int:
    policy = load_policy()
    if not policy.get("enabled"):
        # Fail-safe / opt-in: shield is off → never block.
        return 0

    tool = str(payload.get("tool_name") or "")
    tool_input = payload.get("tool_input") or {}
    if not isinstance(tool_input, dict):
        tool_input = {}

    if tool not in {"WebFetch", "WebSearch", "Bash"}:
        return 0

    targets = extract_targets(tool, tool_input)
    if not targets:
        # Nothing extractable → cannot judge; fail-safe → allow.
        return 0

    allowlist = policy.get("allowlist", [])
    for host in targets:
        if not host_allowed(host, allowlist):
            emit_block_stderr(tool, host)
            emit_block_audit(tool, host, allowlist)
            return 2  # BLOCK
    return 0


def main() -> int:
    raw = sys.stdin.read(262144) if not sys.stdin.isatty() else ""
    if not raw:
        return 0
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError:
        return 0  # fail-safe
    if not isinstance(payload, dict):
        return 0
    return handle(payload)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Fail-safe: any unhandled error → allow. Operator fixes config.
        sys.exit(0)
