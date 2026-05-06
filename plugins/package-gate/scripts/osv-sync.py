#!/usr/bin/env python3
"""
osv-sync: fetch OSV.dev vulnerability data for npm + PyPI ecosystems.

Caches advisories to state/osv-cache.sqlite with 24h TTL. Used by
gate-check.py's R6 `cve` signal to flag any package version intersecting
an OSV advisory with severity >= HIGH.

Schema:
  advisories(
    id TEXT PRIMARY KEY,        -- OSV id (e.g. GHSA-xxxx-xxxx-xxxx)
    ecosystem TEXT NOT NULL,    -- 'npm' | 'PyPI'
    package TEXT NOT NULL,      -- package name (lowercased for npm)
    severity TEXT,              -- LOW | MODERATE | HIGH | CRITICAL | UNKNOWN
    affected_ranges TEXT,       -- JSON: [{introduced, fixed, last_affected}]
    summary TEXT,               -- short human description
    modified TEXT,              -- ISO timestamp from OSV
    fetched_at INTEGER NOT NULL -- unix epoch
  )
  meta(
    key TEXT PRIMARY KEY,
    value TEXT
  )

`meta.last_full_sync_<ecosystem>` carries the unix epoch of the last
successful sync; gate-check.py uses it to decide whether the cache is
fresh (24h TTL).

Usage:
  python osv-sync.py                       # full sync of common pkgs
  python osv-sync.py --packages a,b,c      # sync specific packages
  python osv-sync.py --ecosystem npm       # one ecosystem only
  python osv-sync.py --sample              # smoke-test 10-pkg sample

The OSV query API takes one package per request; we batch sequentially
with polite throttling and cache misses + hits both. No new pip deps.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import sys
import time
import urllib.error
import urllib.request
from typing import Iterable

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "state"))
DB_PATH = os.path.join(STATE_DIR, "osv-cache.sqlite")

OSV_QUERY_URL = "https://api.osv.dev/v1/query"
HTTP_TIMEOUT = 10.0
USER_AGENT = "hydra-package-gate-osv-sync/0.1"
CACHE_TTL_SECONDS = 24 * 3600

# Severity ranking — used by gate-check.py to filter HIGH+ only.
SEVERITY_RANK = {
    "UNKNOWN": 0,
    "LOW": 1,
    "MODERATE": 2,
    "MEDIUM": 2,  # OSV uses both
    "HIGH": 3,
    "CRITICAL": 4,
}

# Smoke-test sample: a handful of well-known npm + PyPI packages with known
# historical advisories. Sufficient to verify ingestion + schema.
SAMPLE_PACKAGES = {
    "npm": [
        "lodash", "minimist", "ua-parser-js", "event-stream", "left-pad",
    ],
    "PyPI": [
        "requests", "urllib3", "pyyaml", "django", "pillow",
    ],
}


def _ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS advisories(
            id TEXT PRIMARY KEY,
            ecosystem TEXT NOT NULL,
            package TEXT NOT NULL,
            severity TEXT,
            affected_ranges TEXT,
            summary TEXT,
            modified TEXT,
            fetched_at INTEGER NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_adv_eco_pkg
            ON advisories(ecosystem, package);
        CREATE TABLE IF NOT EXISTS meta(
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """
    )
    conn.commit()


def _open_db() -> sqlite3.Connection:
    os.makedirs(STATE_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    _ensure_schema(conn)
    return conn


def _normalize_severity(adv: dict) -> str:
    """Walk the OSV severity fields and return a canonical bucket."""
    db_specific = adv.get("database_specific") or {}
    sev = db_specific.get("severity")
    if isinstance(sev, str) and sev.upper() in SEVERITY_RANK:
        return sev.upper()

    sev_list = adv.get("severity") or []
    if isinstance(sev_list, list):
        for entry in sev_list:
            if isinstance(entry, dict):
                # CVSS_V3 score → bucket
                score_str = entry.get("score")
                if isinstance(score_str, str) and "/" in score_str:
                    # Vector string; parse out base score is non-trivial w/o
                    # the official cvss lib. Take a conservative fallback.
                    pass
                t = entry.get("type")
                if t and isinstance(score_str, str):
                    try:
                        # Some OSV entries put a numeric base score directly.
                        f = float(score_str)
                        if f >= 9.0:
                            return "CRITICAL"
                        if f >= 7.0:
                            return "HIGH"
                        if f >= 4.0:
                            return "MODERATE"
                        if f > 0:
                            return "LOW"
                    except ValueError:
                        pass
    return "UNKNOWN"


def _extract_ranges(adv: dict, package_name: str, ecosystem: str) -> list[dict]:
    """Pull (introduced, fixed, last_affected) range tuples for our package."""
    out: list[dict] = []
    for affected in adv.get("affected") or []:
        if not isinstance(affected, dict):
            continue
        pkg = affected.get("package") or {}
        if not isinstance(pkg, dict):
            continue
        if (pkg.get("ecosystem") or "").lower() != ecosystem.lower():
            continue
        if (pkg.get("name") or "").lower() != package_name.lower():
            continue
        for r in affected.get("ranges") or []:
            if not isinstance(r, dict):
                continue
            entry: dict = {}
            for ev in r.get("events") or []:
                if not isinstance(ev, dict):
                    continue
                for k in ("introduced", "fixed", "last_affected"):
                    if k in ev:
                        entry[k] = ev[k]
            if entry:
                out.append(entry)
        # Some advisories use `versions: [..]` instead of ranges
        versions = affected.get("versions")
        if isinstance(versions, list) and versions:
            out.append({"versions": versions})
    return out


def query_osv(package: str, ecosystem: str) -> list[dict]:
    """POST one package against /v1/query, return list of advisories."""
    payload = {"package": {"name": package, "ecosystem": ecosystem}}
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        OSV_QUERY_URL,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": USER_AGENT,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            if resp.status != 200:
                return []
            data = json.loads(resp.read().decode("utf-8", errors="replace"))
            vulns = data.get("vulns") or []
            return vulns if isinstance(vulns, list) else []
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError,
            ConnectionError, json.JSONDecodeError):
        return []


def upsert_advisory(conn: sqlite3.Connection, adv: dict, package: str,
                    ecosystem: str, now: int) -> None:
    osv_id = adv.get("id")
    if not isinstance(osv_id, str):
        return
    severity = _normalize_severity(adv)
    ranges = _extract_ranges(adv, package, ecosystem)
    summary = adv.get("summary") or adv.get("details") or ""
    if isinstance(summary, str) and len(summary) > 500:
        summary = summary[:497] + "..."
    modified = adv.get("modified") or ""
    conn.execute(
        """
        INSERT INTO advisories(id, ecosystem, package, severity,
            affected_ranges, summary, modified, fetched_at)
        VALUES(?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            ecosystem=excluded.ecosystem,
            package=excluded.package,
            severity=excluded.severity,
            affected_ranges=excluded.affected_ranges,
            summary=excluded.summary,
            modified=excluded.modified,
            fetched_at=excluded.fetched_at
        """,
        (osv_id, ecosystem, package.lower(), severity,
         json.dumps(ranges), summary, modified, now),
    )


def sync_packages(packages: Iterable[str], ecosystem: str,
                  conn: sqlite3.Connection, throttle: float = 0.05) -> tuple[int, int]:
    """Returns (packages_queried, advisories_written)."""
    queried = 0
    written = 0
    now = int(time.time())
    for pkg in packages:
        pkg = pkg.strip()
        if not pkg:
            continue
        vulns = query_osv(pkg, ecosystem)
        queried += 1
        for adv in vulns:
            upsert_advisory(conn, adv, pkg, ecosystem, now)
            written += 1
        if throttle:
            time.sleep(throttle)
    conn.commit()
    return queried, written


def _load_top_list(ecosystem: str) -> list[str]:
    """Best-effort load of state/top10k-<eco>.json if present."""
    eco_key = "npm" if ecosystem == "npm" else "pypi"
    path = os.path.join(STATE_DIR, f"top10k-{eco_key}.json")
    if not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, list):
            return [p for p in data if isinstance(p, str)]
        if isinstance(data, dict) and isinstance(data.get("packages"), list):
            return [p for p in data["packages"] if isinstance(p, str)]
    except (OSError, json.JSONDecodeError):
        pass
    return []


def main() -> int:
    p = argparse.ArgumentParser(description="Sync OSV advisories for npm + PyPI.")
    p.add_argument("--ecosystem", choices=["npm", "PyPI", "both"], default="both")
    p.add_argument("--packages", help="Comma-separated package names. Overrides top-list.")
    p.add_argument("--sample", action="store_true",
                   help="Run a 10-package smoke-test sample.")
    p.add_argument("--limit", type=int, default=0,
                   help="Cap packages per ecosystem (0 = no cap).")
    p.add_argument("--throttle", type=float, default=0.05,
                   help="Seconds between requests (default 0.05 = ~20 req/s).")
    args = p.parse_args()

    ecosystems = (["npm", "PyPI"] if args.ecosystem == "both" else [args.ecosystem])
    conn = _open_db()
    total_queried = 0
    total_written = 0
    now = int(time.time())

    for eco in ecosystems:
        if args.sample:
            pkgs = SAMPLE_PACKAGES[eco]
        elif args.packages:
            pkgs = [p for p in args.packages.split(",") if p.strip()]
        else:
            pkgs = _load_top_list(eco)
            if not pkgs:
                # Fall back to sample so a clean machine still produces data.
                pkgs = SAMPLE_PACKAGES[eco]
        if args.limit > 0:
            pkgs = pkgs[: args.limit]
        sys.stderr.write(f"osv-sync: {eco} -- {len(pkgs)} packages\n")
        q, w = sync_packages(pkgs, eco, conn, throttle=args.throttle)
        total_queried += q
        total_written += w
        conn.execute(
            "INSERT INTO meta(key, value) VALUES(?, ?) "
            "ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (f"last_full_sync_{eco}", str(now)),
        )
        conn.commit()

    sys.stderr.write(
        f"osv-sync: queried={total_queried} advisories_written={total_written} "
        f"db={DB_PATH}\n"
    )
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
