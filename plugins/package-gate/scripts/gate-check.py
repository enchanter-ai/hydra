#!/usr/bin/env python3
"""
package-gate: advisory pre-install supply-chain check.

Reads a shell command, extracts package install targets, runs 5 risk checks
against public registries, and prints an advisory block to STDERR. Always
exits 0 — this script's caller (pretooluse.sh) is the hook contract surface.

Risk signals (per plugin spec):
  R1 existence       — package missing from registry → slopsquat-or-typo
  R2 age             — first publish < 30 days       → recent
  R3 maintainer      — last publish > 2 years OR     → stale-or-handover
                       maintainer churn indicators
  R4 typosquat       — Levenshtein <= 2 to top list  → typosquat
  R5 download cliff  — weekly downloads < 100        → low-adoption

Reuses levenshtein_distance from hydra/shared/scripts/supply-chain.py.

Working ecosystems in this draft: npm, pip.
TODO ecosystems (clearly stubbed): pnpm/yarn route through npm; cargo, go,
gem, bundle return UNSUPPORTED.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Iterable

# ── Reuse levenshtein from shared supply-chain.py (no duplication) ─────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SHARED_SCRIPTS = os.path.normpath(
    os.path.join(SCRIPT_DIR, "..", "..", "..", "shared", "scripts")
)
if SHARED_SCRIPTS not in sys.path:
    sys.path.insert(0, SHARED_SCRIPTS)
try:
    from supply_chain import levenshtein_distance  # type: ignore
except Exception:
    # supply-chain.py uses a hyphen in its filename; import via importlib.
    import importlib.util
    _spec = importlib.util.spec_from_file_location(
        "supply_chain", os.path.join(SHARED_SCRIPTS, "supply-chain.py")
    )
    if _spec and _spec.loader:
        _mod = importlib.util.module_from_spec(_spec)
        _spec.loader.exec_module(_mod)
        levenshtein_distance = _mod.levenshtein_distance  # type: ignore
    else:
        # Last-resort local copy keeps the hook functional if the import fails.
        def levenshtein_distance(s1: str, s2: str) -> int:  # type: ignore
            if len(s1) < len(s2):
                return levenshtein_distance(s2, s1)
            if len(s2) == 0:
                return len(s1)
            prev = list(range(len(s2) + 1))
            for i, c1 in enumerate(s1):
                curr = [i + 1]
                for j, c2 in enumerate(s2):
                    curr.append(min(prev[j + 1] + 1, curr[j] + 1, prev[j] + (c1 != c2)))
                prev = curr
            return prev[-1]


# ── Constants ──────────────────────────────────────────────────────────────
CACHE_DIR = os.path.join(SCRIPT_DIR, "..", "state", "cache")
CACHE_TTL_SECONDS = 24 * 3600
HTTP_TIMEOUT = 3.0
USER_AGENT = "hydra-package-gate/0.1 (+advisory)"

# Stub seed of frequently-attacked names (top-targeted, not top-by-downloads).
# TODO(bin/refresh-top10k.py): replace with a refreshed top-10k list per
# ecosystem, generated offline and shipped as data/top10k-{npm,pypi}.txt.
TOP_PACKAGES_NPM = {
    "react", "react-dom", "lodash", "axios", "express", "vue", "next",
    "typescript", "webpack", "babel-core", "@babel/core", "eslint",
    "moment", "jquery", "chalk", "commander", "debug", "minimist",
    "left-pad", "request", "underscore", "uuid", "yargs", "rxjs",
}
TOP_PACKAGES_PYPI = {
    "requests", "numpy", "pandas", "tensorflow", "torch", "scipy",
    "django", "flask", "pytest", "pillow", "matplotlib", "scikit-learn",
    "boto3", "click", "pyyaml", "setuptools", "wheel", "urllib3",
    "cryptography", "sqlalchemy", "fastapi", "pydantic", "beautifulsoup4",
    "openai", "anthropic", "langchain",
}

ADVISORY_HEADER = "=== package-gate (advisory) ==="
ADVISORY_FOOTER = (
    "Hint: verify each flag above before installing. This is advisory only; "
    "the install was not blocked."
)
MAX_FINDING_LINES = 60  # body cap; total block stays <= 80 lines including header/footer.


# ── HTTP + cache ───────────────────────────────────────────────────────────
def _cache_path(url: str) -> str:
    h = hashlib.sha1(url.encode("utf-8")).hexdigest()
    return os.path.join(CACHE_DIR, f"{h}.json")


def _read_cache(url: str):
    p = _cache_path(url)
    try:
        st = os.stat(p)
    except OSError:
        return None
    if (time.time() - st.st_mtime) > CACHE_TTL_SECONDS:
        return None
    try:
        with open(p, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return None


def _write_cache(url: str, payload) -> None:
    """Atomic write: temp file in same dir, then os.replace (per web-fetch.md)."""
    try:
        os.makedirs(CACHE_DIR, exist_ok=True)
        target = _cache_path(url)
        tmp = f"{target}.{os.getpid()}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        os.replace(tmp, target)
    except OSError:
        pass  # cache failure is never fatal


def _http_get_json(url: str):
    cached = _read_cache(url)
    if cached is not None:
        return cached
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            if resp.status != 200:
                _write_cache(url, {"_error": f"http_{resp.status}"})
                return {"_error": f"http_{resp.status}"}
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
            _write_cache(url, data)
            return data
    except urllib.error.HTTPError as e:
        payload = {"_error": f"http_{e.code}"}
        _write_cache(url, payload)
        return payload
    except (urllib.error.URLError, TimeoutError, ConnectionError, json.JSONDecodeError):
        return {"_error": "network"}


# ── Command parsing ────────────────────────────────────────────────────────
# Maps detected install verbs to ecosystem.  Order matters: longest first so
# "uv pip install" wins over "uv add".
_INSTALL_PATTERNS: list[tuple[re.Pattern, str]] = [
    (re.compile(r"\bnpm\s+(?:install|i)\b"), "npm"),
    (re.compile(r"\bpnpm\s+add\b"),         "npm"),
    (re.compile(r"\byarn\s+add\b"),         "npm"),
    (re.compile(r"\buv\s+pip\s+install\b"), "pypi"),
    (re.compile(r"\buv\s+add\b"),           "pypi"),
    (re.compile(r"\bpip3?\s+install\b"),    "pypi"),
    (re.compile(r"\bcargo\s+add\b"),        "cargo"),
    (re.compile(r"\bgo\s+get\b"),           "go"),
    (re.compile(r"\bgem\s+install\b"),      "gem"),
    (re.compile(r"\bbundle\s+add\b"),       "bundler"),
]

# Tokens that are flags (skip them as package names).
_FLAG_RE = re.compile(r"^-")


def parse_install(command: str) -> tuple[str | None, list[str]]:
    """Return (ecosystem, [package_names]) — strip flags and version pins."""
    ecosystem: str | None = None
    match: re.Match | None = None
    for pat, eco in _INSTALL_PATTERNS:
        m = pat.search(command)
        if m and (match is None or m.start() < match.start()):
            match = m
            ecosystem = eco
    if not match or not ecosystem:
        return None, []

    rest = command[match.end():]
    try:
        tokens = shlex.split(rest, posix=True)
    except ValueError:
        tokens = rest.split()

    pkgs: list[str] = []
    for tok in tokens:
        if not tok or _FLAG_RE.match(tok):
            continue
        # Stop at shell control / chaining tokens.
        if tok in (";", "&&", "||", "|", ">", ">>", "<"):
            break
        # Strip version pins.
        # npm/yarn/pnpm: pkg@version   (but @scope/name keeps its leading @)
        # pip:           pkg==version, pkg>=v, pkg[extra]
        name = tok
        if name.startswith("@"):
            # @scope/name@version → keep @scope/name
            parts = name.split("@")
            if len(parts) >= 3:
                name = "@" + parts[1]
        else:
            name = name.split("@", 1)[0]
        name = re.split(r"[<>=!~\[]", name, maxsplit=1)[0].strip()
        if name and not name.startswith("-"):
            pkgs.append(name)
    return ecosystem, pkgs


# ── Risk checks per ecosystem ──────────────────────────────────────────────
def _typosquat_finding(name: str, top: Iterable[str]) -> str | None:
    name_l = name.lower()
    if name_l in top:
        return None
    for cand in top:
        d = levenshtein_distance(name_l, cand)
        if 0 < d <= 2:
            return cand
    return None


def _days_since(iso_str: str) -> int | None:
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int((datetime.now(timezone.utc) - dt).total_seconds() // 86400)


def check_npm(pkg: str) -> list[tuple[str, str, str]]:
    """Return list of (severity, signal, reason) tuples."""
    findings: list[tuple[str, str, str]] = []

    # R4 typosquat — runs even when registry is unreachable.
    target = _typosquat_finding(pkg, TOP_PACKAGES_NPM)
    if target:
        findings.append(("HIGH", "typosquat", f"Levenshtein <= 2 to popular '{target}'"))

    meta = _http_get_json(f"https://registry.npmjs.org/{pkg}")
    if "_error" in meta:
        if meta["_error"] == "http_404":
            findings.append(("HIGH", "slopsquat-or-typo", "not found in npm registry"))
            return findings
        # Other errors: skip silently (offline / rate-limit) — don't false-flag.
        return findings

    # R2 age — first-publish via time.created
    times = meta.get("time", {}) if isinstance(meta, dict) else {}
    created = times.get("created")
    modified = times.get("modified")
    if isinstance(created, str):
        d = _days_since(created)
        if d is not None and d < 30:
            findings.append(("HIGH", "recent", f"first published {d}d ago"))

    # R3 maintainer — last publish > 2y, or single maintainer with churn cue
    if isinstance(modified, str):
        d = _days_since(modified)
        if d is not None and d > 730:
            findings.append(("MEDIUM", "stale-or-handover", f"no publish in {d}d"))
    maintainers = meta.get("maintainers") or []
    if isinstance(maintainers, list) and len(maintainers) == 0:
        findings.append(("MEDIUM", "stale-or-handover", "no maintainers listed"))

    # R5 download cliff
    dl = _http_get_json(f"https://api.npmjs.org/downloads/point/last-week/{pkg}")
    if isinstance(dl, dict) and "_error" not in dl:
        weekly = dl.get("downloads")
        if isinstance(weekly, int) and weekly < 100:
            findings.append(("MEDIUM", "low-adoption", f"{weekly} weekly downloads"))

    return findings


def check_pypi(pkg: str) -> list[tuple[str, str, str]]:
    findings: list[tuple[str, str, str]] = []

    target = _typosquat_finding(pkg, TOP_PACKAGES_PYPI)
    if target:
        findings.append(("HIGH", "typosquat", f"Levenshtein <= 2 to popular '{target}'"))

    meta = _http_get_json(f"https://pypi.org/pypi/{pkg}/json")
    if "_error" in meta:
        if meta["_error"] == "http_404":
            findings.append(("HIGH", "slopsquat-or-typo", "not found on PyPI"))
            return findings
        return findings

    releases = meta.get("releases") or {}
    if isinstance(releases, dict) and releases:
        upload_dates: list[str] = []
        for files in releases.values():
            if isinstance(files, list):
                for f in files:
                    if isinstance(f, dict):
                        u = f.get("upload_time_iso_8601") or f.get("upload_time")
                        if isinstance(u, str):
                            upload_dates.append(u)
        upload_dates.sort()
        if upload_dates:
            first_d = _days_since(upload_dates[0])
            last_d = _days_since(upload_dates[-1])
            if first_d is not None and first_d < 30:
                findings.append(("HIGH", "recent", f"first published {first_d}d ago"))
            if last_d is not None and last_d > 730:
                findings.append(("MEDIUM", "stale-or-handover", f"no release in {last_d}d"))

    info = meta.get("info") or {}
    if isinstance(info, dict):
        # PyPI doesn't expose per-package maintainer churn directly; use
        # the `author` / `maintainer` fields as a weak handover cue.
        if not any(info.get(k) for k in ("author", "maintainer", "author_email", "maintainer_email")):
            findings.append(("MEDIUM", "stale-or-handover", "no author/maintainer metadata"))

    # R5 download cliff via pypistats
    dl = _http_get_json(f"https://pypistats.org/api/packages/{pkg}/recent")
    if isinstance(dl, dict) and "_error" not in dl:
        data = dl.get("data") or {}
        if isinstance(data, dict):
            weekly = data.get("last_week")
            if isinstance(weekly, int) and weekly < 100:
                findings.append(("MEDIUM", "low-adoption", f"{weekly} weekly downloads"))

    return findings


# TODO(ecosystem-stubs): cargo, go, gem, bundler are recognized so we can warn
# the user that this draft doesn't cover them, rather than silently skipping.
def check_unsupported(pkg: str, eco: str) -> list[tuple[str, str, str]]:
    return [("INFO", "unsupported", f"package-gate has no checks for {eco} yet")]


# ── Output ─────────────────────────────────────────────────────────────────
_SEVERITY_RANK = {"HIGH": 0, "MEDIUM": 1, "INFO": 2}


def emit(findings: list[tuple[str, str, str, str]]) -> None:
    """findings: list of (pkg, severity, signal, reason). Empty → silent."""
    if not findings:
        return
    findings.sort(key=lambda x: (_SEVERITY_RANK.get(x[1], 9), x[0]))
    sys.stderr.write(ADVISORY_HEADER + "\n")
    for i, (pkg, sev, signal, reason) in enumerate(findings):
        if i >= MAX_FINDING_LINES:
            sys.stderr.write(f"...and {len(findings) - MAX_FINDING_LINES} more.\n")
            break
        sys.stderr.write(f"[{sev}] {pkg} -- {signal}: {reason}\n")
    sys.stderr.write(ADVISORY_FOOTER + "\n")


def main() -> int:
    if len(sys.argv) < 2:
        return 0
    command = sys.argv[1]
    eco, pkgs = parse_install(command)
    if not eco or not pkgs:
        return 0

    out: list[tuple[str, str, str, str]] = []
    for pkg in pkgs[:20]:  # cap defensive: don't probe a 100-pkg one-liner
        if eco == "npm":
            results = check_npm(pkg)
        elif eco == "pypi":
            results = check_pypi(pkg)
        else:
            results = check_unsupported(pkg, eco)
        for sev, signal, reason in results:
            out.append((pkg, sev, signal, reason))
    emit(out)
    return 0


if __name__ == "__main__":
    # Even an unhandled exception must not propagate — the hook wrapper also
    # forces exit 0, but defense-in-depth.
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
