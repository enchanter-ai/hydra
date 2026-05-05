# package-gate

Advisory PreToolUse gate on package install commands. Runs 5 risk checks against public registries before `npm install` / `pip install` / `pnpm add` / `yarn add` / `uv add` runs, and injects a one-block summary into the conversation as stderr advisory output. **Always exits 0; never blocks.**

## Why

Modern supply-chain attacks (xz-utils 2024, polyfill.io 2024, ua-parser-js 2021, event-stream 2018) ship through third-party packages, and `postinstall` scripts run before any vuln scanner sees the tree. The existing `hydra/shared/scripts/supply-chain.py` catches slopsquatted/typosquatted imports already in code — this plugin catches them at the install boundary, advisory-only, before `node_modules` exists.

## Install

Part of the [Hydra](../..) bundle.

```
/plugin marketplace add enchanted-plugins/hydra
/plugin install hydra-package-gate@hydra
```

## What it checks (5 signals)

| Signal | Trigger | Severity |
|---|---|---|
| `slopsquat-or-typo` | Package not found in registry | HIGH |
| `typosquat` | Levenshtein <= 2 vs. seed list of popular names | HIGH |
| `recent` | First publish < 30 days ago | HIGH |
| `stale-or-handover` | No publish in > 2 years OR missing maintainer metadata | MEDIUM |
| `low-adoption` | < 100 weekly downloads | MEDIUM |

## Hook

- **PreToolUse** on `Bash` — pre-filters for install verbs (npm/pnpm/yarn/pip/uv/cargo/go/gem/bundle) before invoking the python checker.
- **Always exits 0.** Hook contract is observe-and-inject, never deny. See `wixie/shared/conduct/hooks.md`.
- **Latency budget:** ~5 seconds. Wider than the typical PreToolUse <50ms because installs themselves take multiple seconds; the advisory check fits inside the user's existing wait. Documented exception, not a precedent.
- **Cache:** `state/cache/<sha1-of-url>.json`, 24-hour mtime TTL, atomic `os.replace` write — per `wixie/shared/conduct/web-fetch.md`.

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

All read-only GET. No package contents are fetched and nothing is written to your `node_modules` / venv during the check.

## Top-package seed

Ships with a ~50-entry seed of frequently-attacked package names (used for typosquat distance checks). **TODO:** `bin/refresh-top10k.py` to generate a real top-10k list per ecosystem from registry stats. Until then the typosquat check is best-effort against the most-attacked names, not exhaustive.

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
