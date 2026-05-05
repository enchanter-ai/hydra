#!/usr/bin/env python3
"""License compliance scanner.

Detects npm (package.json) and Python (pyproject.toml / requirements.txt) projects,
shells out to `npx license-checker --json` and `pip-licenses --format=json`,
classifies each dep against state/policy.json, and emits stderr advisories.

Always exits 0 (advisory) unless --fail-on-deny is passed AND a deny is found.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_POLICY = PLUGIN_ROOT / "state" / "policy.json"


def load_policy(path: Path) -> dict:
    if not path.exists():
        print(f"[license-gate] policy file not found: {path}", file=sys.stderr)
        return {"allow": [], "deny": [], "warn": []}
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def detect_ecosystems(project: Path) -> list[str]:
    found: list[str] = []
    if (project / "package.json").exists():
        found.append("npm")
    if (project / "pyproject.toml").exists() or (project / "requirements.txt").exists():
        found.append("python")
    return found


def normalize(license_str: str | None) -> list[str]:
    """Split SPDX expressions like 'MIT OR Apache-2.0' / '(MIT AND BSD-3-Clause)' into atoms."""
    if not license_str:
        return ["UNKNOWN"]
    atoms = re.split(r"\s+(?:OR|AND|WITH)\s+|[(),]", license_str)
    return [a.strip() for a in atoms if a and a.strip()]


def classify(license_atoms: list[str], policy: dict) -> str:
    """Return 'deny' if any atom denied, else 'warn' if any warned, else 'allow' if any allowed, else 'unknown'."""
    deny = set(policy.get("deny", []))
    warn = set(policy.get("warn", []))
    allow = set(policy.get("allow", []))
    if any(a in deny for a in license_atoms):
        return "deny"
    if any(a in warn for a in license_atoms):
        return "warn"
    if any(a in allow for a in license_atoms):
        return "allow"
    return "unknown"


def scan_npm(project: Path) -> list[dict]:
    """Run npx license-checker and return list of {pkg, ver, license}."""
    if not (project / "node_modules").exists():
        print(
            "[license-gate] npm: node_modules/ missing — run `npm install` before scanning.",
            file=sys.stderr,
        )
        return []
    try:
        proc = subprocess.run(
            ["npx", "--yes", "license-checker", "--json"],
            cwd=project,
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
    except FileNotFoundError:
        print("[license-gate] npm: `npx` not on PATH — skipping.", file=sys.stderr)
        return []
    except subprocess.TimeoutExpired:
        print("[license-gate] npm: license-checker timed out.", file=sys.stderr)
        return []
    if proc.returncode != 0:
        print(f"[license-gate] npm: license-checker failed: {proc.stderr.strip()}", file=sys.stderr)
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("[license-gate] npm: license-checker output not JSON.", file=sys.stderr)
        return []
    out: list[dict] = []
    for key, info in data.items():
        # key shape: "pkgname@version"
        if "@" in key[1:]:
            idx = key.rindex("@")
            pkg, ver = key[:idx], key[idx + 1 :]
        else:
            pkg, ver = key, ""
        lic = info.get("licenses")
        if isinstance(lic, list):
            lic = " OR ".join(str(x) for x in lic)
        out.append({"pkg": pkg, "ver": ver, "license": lic or "UNKNOWN", "ecosystem": "npm"})
    return out


def scan_python(project: Path) -> list[dict]:
    """Run pip-licenses --format=json and return list of {pkg, ver, license}."""
    if not shutil.which("pip-licenses"):
        print(
            "[license-gate] python: `pip-licenses` not installed — `pip install pip-licenses` to enable.",
            file=sys.stderr,
        )
        return []
    try:
        proc = subprocess.run(
            ["pip-licenses", "--format=json"],
            cwd=project,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
    except subprocess.TimeoutExpired:
        print("[license-gate] python: pip-licenses timed out.", file=sys.stderr)
        return []
    if proc.returncode != 0:
        print(f"[license-gate] python: pip-licenses failed: {proc.stderr.strip()}", file=sys.stderr)
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("[license-gate] python: pip-licenses output not JSON.", file=sys.stderr)
        return []
    out: list[dict] = []
    for entry in data:
        out.append(
            {
                "pkg": entry.get("Name", "?"),
                "ver": entry.get("Version", ""),
                "license": entry.get("License", "UNKNOWN") or "UNKNOWN",
                "ecosystem": "python",
            }
        )
    return out


def emit_advisories(deps: list[dict], policy: dict) -> tuple[int, int, int]:
    """Print stderr advisories. Return (deny_count, warn_count, allow_count)."""
    denies = warns = allows = 0
    for d in deps:
        atoms = normalize(d["license"])
        verdict = classify(atoms, policy)
        if verdict == "deny":
            denies += 1
            print(
                f"[CRITICAL] {d['pkg']}@{d['ver']} licensed {d['license']} — DENIED by policy. Block release.",
                file=sys.stderr,
            )
        elif verdict == "warn":
            warns += 1
            print(
                f"[MEDIUM] {d['pkg']}@{d['ver']} licensed {d['license']} — review.",
                file=sys.stderr,
            )
        else:
            allows += 1
    return denies, warns, allows


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="License compliance scanner (advisory).")
    parser.add_argument("project", nargs="?", default=".", help="Project root (default: cwd).")
    parser.add_argument(
        "--policy",
        default=str(DEFAULT_POLICY),
        help=f"Path to policy.json (default: {DEFAULT_POLICY}).",
    )
    parser.add_argument(
        "--fail-on-deny",
        action="store_true",
        help="Exit non-zero if any DENY licenses are found (PR/release gating only — not for hooks).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a structured JSON summary on stdout.",
    )
    args = parser.parse_args(argv)

    project = Path(args.project).resolve()
    if not project.exists():
        print(f"[license-gate] project path does not exist: {project}", file=sys.stderr)
        return 0

    policy = load_policy(Path(args.policy))
    ecosystems = detect_ecosystems(project)
    if not ecosystems:
        print(
            f"[license-gate] no package.json / pyproject.toml / requirements.txt at {project} — nothing to scan.",
            file=sys.stderr,
        )
        if args.json:
            print(json.dumps({"project": str(project), "ecosystems": [], "deps": [], "summary": {"deny": 0, "warn": 0, "allow": 0}}))
        return 0

    deps: list[dict] = []
    if "npm" in ecosystems:
        deps.extend(scan_npm(project))
    if "python" in ecosystems:
        deps.extend(scan_python(project))

    denies, warns, allows = emit_advisories(deps, policy)

    summary = {
        "project": str(project),
        "ecosystems": ecosystems,
        "deps": deps,
        "summary": {"deny": denies, "warn": warns, "allow": allows, "total": len(deps)},
    }
    if args.json:
        print(json.dumps(summary, indent=2))
    else:
        print(
            f"[license-gate] scanned {len(deps)} deps across {ecosystems}: "
            f"{denies} deny, {warns} warn, {allows} allow.",
            file=sys.stderr,
        )

    if args.fail_on_deny and denies > 0:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
