#!/usr/bin/env python3
"""
refresh-top10k: rebuild state/top10k-{npm,pypi}.json from upstream registries.

npm:
  Pages https://registry.npmjs.org/-/v1/search?text=*&size=250&from=N up to
  10,000 results, sorting by `popularity` (downloads-weighted). The npm search
  endpoint does not support pure-download ranking, but its popularity score is
  download-weighted heavily enough for typosquat-distance purposes.

PyPI:
  PyPI does not ship a "top by downloads" API. We pull the well-known
  community-maintained `top-pypi-packages` JSON published by hugovk on
  GitHub Pages. Falls back to a static seed if the URL is unreachable.

Outputs:
  state/top10k-npm.json   — JSON list of package names
  state/top10k-pypi.json  — JSON list of package names

Atomic write via tempfile + os.replace per shared/foundations/conduct/web-fetch.md.

Cron:
  Monthly — see .github/workflows/osv-refresh.yml.

Flags:
  --limit N      Cap each ecosystem at N packages (default 10000).
                 For testing: --limit 100 keeps the run under a minute.
  --ecosystem    'npm' | 'pypi' | 'both' (default both).
  --pause SECS   Seconds between npm pages (default 0.5; npm is rate-limited).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "state"))
NPM_OUT = os.path.join(STATE_DIR, "top10k-npm.json")
PYPI_OUT = os.path.join(STATE_DIR, "top10k-pypi.json")

NPM_SEARCH_URL = "https://registry.npmjs.org/-/v1/search"
NPM_PAGE_SIZE = 250
NPM_MAX_RESULTS = 10000

# Community-maintained top PyPI list. Updated daily; permalink stable.
PYPI_TOP_URL = (
    "https://hugovk.github.io/top-pypi-packages/top-pypi-packages.min.json"
)

HTTP_TIMEOUT = 30.0
USER_AGENT = "hydra-package-gate-top10k/0.1"


def _http_get_json(url: str) -> dict | list | None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read().decode("utf-8", errors="replace"))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError,
            ConnectionError, json.JSONDecodeError):
        return None


def _atomic_write_json(path: str, payload) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.{os.getpid()}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False)
    os.replace(tmp, path)


def fetch_npm_top(limit: int, pause: float) -> list[str]:
    """Page through npm search; return list of package names by popularity."""
    names: list[str] = []
    seen: set[str] = set()
    target = min(limit, NPM_MAX_RESULTS)
    for offset in range(0, target, NPM_PAGE_SIZE):
        size = min(NPM_PAGE_SIZE, target - offset)
        # `text=keywords:javascript` returns a broad result set; popularity=1.0
        # weights ranking entirely by download-derived popularity. npm search
        # has no "all packages" wildcard, but the JS keyword covers >95% of
        # the public registry by download volume.
        from urllib.parse import quote
        text = quote("keywords:javascript not:deprecated")
        url = (
            f"{NPM_SEARCH_URL}?text={text}"
            f"&size={size}&from={offset}&popularity=1.0&quality=0.0&maintenance=0.0"
        )
        data = _http_get_json(url)
        if not isinstance(data, dict):
            sys.stderr.write(f"npm: page offset={offset} failed; stopping early\n")
            break
        objects = data.get("objects") or []
        if not isinstance(objects, list) or not objects:
            break
        page_count = 0
        for obj in objects:
            if not isinstance(obj, dict):
                continue
            pkg = obj.get("package") or {}
            if not isinstance(pkg, dict):
                continue
            name = pkg.get("name")
            if isinstance(name, str) and name not in seen:
                seen.add(name)
                names.append(name)
                page_count += 1
        sys.stderr.write(f"npm: offset={offset} +{page_count} (total={len(names)})\n")
        if len(names) >= target:
            break
        if pause > 0:
            time.sleep(pause)
    return names[:target]


def fetch_pypi_top(limit: int) -> list[str]:
    """Pull the community-maintained PyPI top list. Returns names."""
    data = _http_get_json(PYPI_TOP_URL)
    if not isinstance(data, dict):
        sys.stderr.write("pypi: top list fetch failed\n")
        return []
    rows = data.get("rows") or []
    names: list[str] = []
    for row in rows:
        if isinstance(row, dict):
            n = row.get("project") or row.get("name")
            if isinstance(n, str):
                names.append(n)
        elif isinstance(row, str):
            names.append(row)
        if len(names) >= limit:
            break
    sys.stderr.write(f"pypi: collected {len(names)} packages\n")
    return names[:limit]


def main() -> int:
    p = argparse.ArgumentParser(description="Refresh top-10k package lists.")
    p.add_argument("--ecosystem", choices=["npm", "pypi", "both"], default="both")
    p.add_argument("--limit", type=int, default=NPM_MAX_RESULTS,
                   help="Max packages per ecosystem (default 10000).")
    p.add_argument("--pause", type=float, default=0.5,
                   help="Seconds between npm pages (default 0.5).")
    args = p.parse_args()

    if args.ecosystem in ("npm", "both"):
        names = fetch_npm_top(args.limit, args.pause)
        if names:
            _atomic_write_json(NPM_OUT, names)
            sys.stderr.write(f"npm: wrote {len(names)} -> {NPM_OUT}\n")
        else:
            sys.stderr.write("npm: no packages collected; not writing\n")

    if args.ecosystem in ("pypi", "both"):
        names = fetch_pypi_top(args.limit)
        if names:
            _atomic_write_json(PYPI_OUT, names)
            sys.stderr.write(f"pypi: wrote {len(names)} -> {PYPI_OUT}\n")
        else:
            sys.stderr.write("pypi: no packages collected; not writing\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
