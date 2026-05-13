# package-gate

Advisory PreToolUse gate on package install commands. Runs 6 risk checks against public registries before `npm install` / `pip install` / `pnpm add` / `yarn add` / `uv add` runs, and injects a one-block summary into the conversation as stderr advisory output. **Always exits 0; never blocks.**

## Why

Modern supply-chain attacks (xz-utils 2024, polyfill.io 2024, ua-parser-js 2021, event-stream 2018) ship through third-party packages, and `postinstall` scripts run before any vuln scanner sees the tree. The existing `hydra/shared/scripts/supply-chain.py` catches slopsquatted/typosquatted imports already in code — this plugin catches them at the install boundary, advisory-only, before `node_modules` exists.

## Install

Part of the [Hydra](../..) bundle.

```
/plugin marketplace add enchanter-ai/hydra
/plugin install hydra-package-gate@hydra
```

## What it checks (6 signals)

| Signal | Trigger | Severity |
|---|---|---|
| `slopsquat-or-typo` | Package not found in registry | HIGH |
| `typosquat` | Levenshtein <= 2 vs. **top-10k registry-derived list** (`state/top10k-{npm,pypi}.json`) | HIGH |
| `recent` | First publish < 30 days ago | HIGH |
| `cve` | Package matches an OSV.dev advisory at HIGH or CRITICAL severity (cache: `state/osv-cache.sqlite`, daily refresh) | HIGH |
| `stale-or-handover` | No publish in > 2 years OR missing maintainer metadata | MEDIUM |
| `low-adoption` | < 100 weekly downloads | MEDIUM |

## Hook

- **PreToolUse** on `Bash` — pre-filters for install verbs (npm/pnpm/yarn/pip/uv/cargo/go/gem/bundle) before invoking the python checker.
- **Always exits 0.** Hook contract is observe-and-inject, never deny. See `wixie/../vis/packages/core/conduct/hooks.md`.
- **Latency budget:** ~5 seconds. Wider than the typical PreToolUse <50ms because installs themselves take multiple seconds; the advisory check fits inside the user's existing wait. Documented exception, not a precedent.
- **Cache:** `state/cache/<sha1-of-url>.json`, 24-hour mtime TTL, atomic `os.replace` write — per `wixie/../vis/packages/web/conduct/web-fetch.md`.

## Ecosystem coverage

| Ecosystem | Status |
|---|---|
| npm (npm install / pnpm add / yarn add) | Working |
| PyPI (pip install / uv add / uv pip install) | Working |
| Cargo, Go, RubyGems, Bundler | Stubbed — emits `[INFO] unsupported`. See TODO in `scripts/gate-check.py` (`check_unsupported`). |

## APIs called

- `https://registry.npmjs.org/<pkg>` — npm metadata (versions, time, maintainers)
- `https://api.npmjs.org/downloads/point/last-week/<pkg>` — npm weekly downloads
- `https://pypi.org/pypi/<pkg>/json` — PyPI metadata (releases, info)
- `https://pypistats.org/api/packages/<pkg>/recent` — PyPI weekly downloads
- `https://api.osv.dev/v1/query` — OSV advisory query (POST, used by `osv-sync.py`)
- `https://registry.npmjs.org/-/v1/search` — npm popularity-sorted search (used by `bin/refresh-top10k.py`)
- `https://hugovk.github.io/top-pypi-packages/top-pypi-packages.min.json` — PyPI top-list source (used by `bin/refresh-top10k.py`)

All read-only GET (or POST for OSV query). No package contents are fetched and nothing is written to your `node_modules` / venv during the check.

## CVE feed (R6)

`scripts/osv-sync.py` POSTs each tracked package against `https://api.osv.dev/v1/query` and writes advisories to a local SQLite cache at `state/osv-cache.sqlite`. `gate-check.py` opens the cache read-only and emits a HIGH `cve` finding for any package matching an advisory at severity `HIGH` or `CRITICAL`.

- **Refresh schedule:** daily via `.github/workflows/osv-refresh.yml` (cron `0 3 * * *`). The workflow opens a PR when the SQLite cache changes so a human reviews advisory churn.
- **Cache freshness:** R6 tolerates up to 7 days of staleness before going silent — a one-day missed cron does not blind the check.
- **Manual sync:**
  - Sample (smoke test): `python scripts/osv-sync.py --sample`
  - Full sync: `python scripts/osv-sync.py --ecosystem both`
  - Specific packages: `python scripts/osv-sync.py --packages lodash,minimist`

## Top-10k registry-derived seed

The typosquat check runs Levenshtein distance against the live top-10k lists for each ecosystem, refreshed monthly:

- `state/top10k-npm.json` — populated from `https://registry.npmjs.org/-/v1/search` (popularity-weighted, paged 250-at-a-time)
- `state/top10k-pypi.json` — populated from the community-maintained `top-pypi-packages` JSON (PyPI does not expose a download-ranked API)

If those files are missing (clean install, never refreshed, or offline), `gate-check.py` falls back to a ~50-entry static seed so the check still produces *some* signal.

- **Refresh schedule:** monthly via `.github/workflows/osv-refresh.yml` (cron `0 4 1 * *`).
- **Manual refresh:**
  - Test run: `python bin/refresh-top10k.py --limit 100`
  - Full refresh: `python bin/refresh-top10k.py --ecosystem both`

## Skill

`/skill gate-awareness` (Haiku) — interprets advisory findings and recommends next steps. Never claims a package is malicious; signals are probabilistic.

## Relationship to other Hydra plugins

- `package-gate` (this) catches risk **before** install.
- `vuln-detector` catches code that misuses an already-installed package.
- `secret-scanner` catches credentials that leak **out**.
- `supply-chain.py` (shared/scripts) catches slopsquat imports already in the tree.

Each closes one slice of the supply chain. Removing this plugin leaves the pre-install slice uncovered, but does not break the others — it is advisory and not load-bearing.

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, web-fetch, precedent.
