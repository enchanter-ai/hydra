# Cross-Repo Versioning Strategy

## Shape of the problem

The enchanter-ai ecosystem is **polyrepo by topology, monorepo by contract**. Each plugin repo (wixie, hydra, sylph, djinn, …) lives independently, but they all consume the same shared conduct modules, taxonomy, and engine derivations sourced here, in `agent-foundations`. A change to `shared/conduct/discipline.md` is, in practice, a change to every plugin's behavioral contract.

That means versioning has to answer two questions at once:

1. **What version of the conduct contract does this repo ship against?**
2. **How does a conduct change propagate from `agent-foundations` to the rest of the ecosystem?**

## Current strategy (Phase 1, 2026)

### Single source of truth

`agent-foundations` is the canonical home for:

- `shared/conduct/*.md` — behavioral modules
- `taxonomy/` — failure-mode codes (F01-F14+)
- `engines/` — derivations (E0-E6 etc.)
- `recipes/` and `runbooks/` — cross-plugin patterns

No other repo edits these in place. Downstream plugins read them via the conduct-abi.yml propagation pipeline (see F-026).

### Changesets governs versioning here

This repo runs `@changesets/cli` against the meta-package `@enchanter-ai/agent-foundations-meta`. Every conduct, taxonomy, or engine change ships with a changeset. CI auto-opens a Versions PR; merging it bumps the version and (eventually) publishes.

See `.changeset/README.md` for the operator workflow.

### Per-plugin repos version independently

Each plugin repo (wixie, hydra, …) maintains its own `package.json` and version cadence. They are NOT slaved to `agent-foundations` versions today. Reasons:

- Plugins iterate on different cadences — wixie ships often, hydra rarely.
- Plugin-internal changes (new skill, new hook) don't need a conduct bump to release.
- Coupling all repos to one version would force lockstep releases that nobody wants.

What plugins DO track: a `CONDUCT_VERSION` marker (or equivalent) noting which `agent-foundations` version their conduct mirror was sourced from. The conduct-abi.yml CI flags drift.

### Conduct propagation via conduct-abi.yml (F-026)

When `agent-foundations` ships a conduct change:

1. Changeset bumps the meta-package version on this repo.
2. `conduct-abi.yml` workflow runs (on this repo's main).
3. The workflow opens a sync PR in each downstream plugin repo updating the mirrored conduct files and bumping the local `CONDUCT_VERSION` marker.
4. Each plugin repo reviews and merges on its own cadence.

This gives us monorepo-grade consistency (one source of truth, one version line) without monorepo-grade coupling (lockstep releases).

## Future strategy (Phase 2)

### Conduct as an npm package

Once conduct stabilizes, `agent-foundations` will publish `@enchanter-ai/conduct` to npm:

- Each plugin repo adds `@enchanter-ai/conduct` as a dependency, pinned to a version range.
- Plugin install/setup scripts copy the conduct modules out of `node_modules/@enchanter-ai/conduct/` into the plugin's `shared/conduct/` mirror at install time, so the SKILL.md `@`-references continue to resolve at the same paths.
- Changesets here drive published versions; plugin repos drive their conduct version through their dependency bump cadence.
- The conduct-abi.yml propagation becomes optional — Renovate or Dependabot handles routine bumps; conduct-abi.yml stays for breaking-change blast-radius analysis.

### Why we're not there yet

- Conduct is still mutating fast — promoting it to a published package locks a shape that's still evolving.
- The plugin repos haven't all converged on a Node-based install path; some are pure Python or shell. Resolving conduct via npm assumes a Node toolchain everywhere.
- The mirroring step needs a hook into each plugin's install workflow that doesn't exist yet.

When all three resolve, Phase 2 ships and changesets here will publish on tag instead of just opening a Versions PR.

## TL;DR

- Conduct lives in `agent-foundations`.
- Changesets versions conduct here.
- conduct-abi.yml propagates conduct to downstream plugin repos (Phase 1).
- npm-published `@enchanter-ai/conduct` will replace the propagation pipeline (Phase 2, future).
- Plugin repos version themselves independently of conduct version, but track which conduct version they're synced against.
