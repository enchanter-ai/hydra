#!/usr/bin/env python3
"""
capability-fence: advisory check that the tool being invoked is in the
active skill's declared allowed-tools list.

Inputs:
  - Hook payload on stdin (JSON with `tool_name`, optionally `tool_input`).
  - Optional env: CLAUDE_SKILL_PATH (path to SKILL.md or its containing dir).

Behavior:
  1. Locate the active skill's SKILL.md (env var, else most recent SKILL.md
     under cwd or any ancestor's `skills/`).
  2. Parse YAML frontmatter; extract `allowed-tools` (preferred) or `tools`.
  3. Match the tool_name against the declared list (allowing simple
     `Bash(prefix *)` style entries).
  4. On mismatch: print an advisory block to stderr and append a JSONL row
     to state/fence-log.ndjson via locked append (per templates.md spec G).
  5. Always exit 0.

LIMITATION: cannot block — observability only. Real enforcement requires a
harness-level per-subagent permissions overlay (see README.md).
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# ─────────────────────────── locked JSONL append (spec G) ───────────────────


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


# ─────────────────────────── frontmatter parsing ────────────────────────────

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    """Tiny YAML-subset parser. Handles scalars, inline lists, and block lists.

    Sufficient for SKILL.md frontmatter; not a full YAML implementation.
    """
    m = _FRONTMATTER_RE.match(text)
    if not m:
        return {}
    body = m.group(1)
    out: dict = {}
    cur_key: str | None = None
    cur_list: list | None = None
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        # block list continuation
        if cur_list is not None and re.match(r"^\s+-\s+", line):
            item = line.split("-", 1)[1].strip().strip("\"'")
            cur_list.append(item)
            continue
        # close prior list
        if cur_list is not None:
            out[cur_key] = cur_list  # type: ignore[index]
            cur_list = None
            cur_key = None
        if ":" not in line:
            continue
        key, _, val = line.partition(":")
        key = key.strip()
        val = val.strip()
        if val == "" or val == ">":
            # next lines may form a block list or folded scalar
            cur_key = key
            cur_list = []
            continue
        if val.startswith("[") and val.endswith("]"):
            inner = val[1:-1]
            items = [p.strip().strip("\"'") for p in inner.split(",") if p.strip()]
            out[key] = items
            continue
        out[key] = val.strip("\"'")
    if cur_list is not None and cur_key is not None:
        # Folded scalar (no '-' lines) → join lost; treat as empty list.
        out[cur_key] = cur_list
    return out


def extract_allowed_tools(fm: dict) -> list[str]:
    """Read `allowed-tools` first, then fallback to `tools`. Normalize to list."""
    val = fm.get("allowed-tools")
    if val is None:
        val = fm.get("tools")
    if val is None:
        return []
    if isinstance(val, list):
        return [str(x).strip() for x in val if str(x).strip()]
    s = str(val).strip()
    if not s:
        return []
    # Common SKILL.md form: space-or-comma-separated on one line, e.g.
    # "Bash(python *) Read Write Edit"
    # Split on commas first, then on whitespace if no commas.
    if "," in s:
        return [p.strip() for p in s.split(",") if p.strip()]
    return [p.strip() for p in s.split() if p.strip()]


# ─────────────────────────── skill discovery ────────────────────────────────


def find_active_skill_md(cwd: Path) -> Path | None:
    env = os.environ.get("CLAUDE_SKILL_PATH")
    if env:
        p = Path(env)
        if p.is_file() and p.name == "SKILL.md":
            return p
        if p.is_dir():
            cand = p / "SKILL.md"
            if cand.is_file():
                return cand
    # Walk cwd up to 6 ancestors looking for the most-recently-modified SKILL.md
    candidates: list[Path] = []
    cur = cwd
    for _ in range(6):
        if (cur / "SKILL.md").is_file():
            candidates.append(cur / "SKILL.md")
        skills_dir = cur / "skills"
        if skills_dir.is_dir():
            for sub in skills_dir.iterdir():
                sm = sub / "SKILL.md"
                if sm.is_file():
                    candidates.append(sm)
        cur = cur.parent
        if cur == cur.parent:
            break
    if not candidates:
        return None
    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return candidates[0]


# ─────────────────────────── tool matching ──────────────────────────────────

# Bash(...) declarations look like: Bash(python *), Bash(npm install *)
_BASH_DECL_RE = re.compile(r"^Bash\((.+)\)$")


def tool_matches_decl(tool_name: str, tool_input: dict, decl: str) -> bool:
    decl = decl.strip()
    if not decl:
        return False
    # Exact tool-name match (Read, Write, Edit, Bash, Grep, Glob, Agent, ...)
    if decl == tool_name:
        return True
    # Bash(prefix *) — the user-pinned subset form.
    m = _BASH_DECL_RE.match(decl)
    if m and tool_name == "Bash":
        pattern = m.group(1).strip()
        cmd = ""
        if isinstance(tool_input, dict):
            cmd = str(tool_input.get("command", ""))
        # Allow glob-style match against the actual command string.
        if fnmatch.fnmatchcase(cmd, pattern) or cmd.startswith(pattern.rstrip("*").strip()):
            return True
    return False


def is_tool_allowed(tool_name: str, tool_input: dict, allowed: list[str]) -> bool:
    if not allowed:
        # No declared list → cannot judge. Treat as allowed (advisory only).
        return True
    return any(tool_matches_decl(tool_name, tool_input, d) for d in allowed)


# ─────────────────────────── main ───────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plugin-root", required=True)
    args = ap.parse_args()

    plugin_root = Path(args.plugin_root)
    log_path = plugin_root / "state" / "fence-log.ndjson"

    raw = sys.stdin.read()
    if not raw.strip():
        return 0
    try:
        payload = json.loads(raw)
    except Exception:
        return 0

    tool_name = str(payload.get("tool_name") or "").strip()
    tool_input = payload.get("tool_input") or {}
    if not tool_name:
        return 0

    skill_md = find_active_skill_md(Path.cwd())
    if skill_md is None:
        return 0

    try:
        text = skill_md.read_text(encoding="utf-8")
    except Exception:
        return 0
    fm = parse_frontmatter(text)
    allowed = extract_allowed_tools(fm)
    if not allowed:
        # Skill declared no whitelist — nothing to compare against.
        return 0

    if is_tool_allowed(tool_name, tool_input, allowed):
        return 0

    skill_name = str(fm.get("name") or skill_md.parent.name)
    allowed_str = ", ".join(allowed)

    print("=== capability-fence (advisory) ===", file=sys.stderr)
    print(
        f"Skill {skill_name} is invoking {tool_name} which is NOT in its "
        f"declared allowed-tools list ({allowed_str}). "
        "Possible subagent escape. Review delegation.md.",
        file=sys.stderr,
    )

    # Append to fence-log.ndjson via locked append.
    try:
        row = {
            "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "epoch": int(time.time()),
            "skill_name": skill_name,
            "skill_md": str(skill_md),
            "tool_name": tool_name,
            "allowed_tools": allowed,
            "verdict": "out-of-lane",
            "advisory_only": True,
        }
        append_jsonl_locked(log_path, json.dumps(row, ensure_ascii=False))
    except Exception:
        pass

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Advisory contract: never propagate failure.
        sys.exit(0)
