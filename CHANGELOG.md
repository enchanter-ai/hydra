# Changelog

All notable changes to `hydra` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] — rename: hydra identity, standardized origin format

### Added
- Tier-1 governance docs: `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, `CHANGELOG.md`.
- `.github/` scaffold: issue templates, PR template, CODEOWNERS, dependabot config.
- Tier-2 docs: `docs/getting-started.md`, `docs/installation.md`, `docs/troubleshooting.md`, `docs/adr/README.md`.

## [1.0.0] — defense-in-depth, zero runtime deps

The current shipped release. See [README.md](README.md) for the complete feature surface.

### Highlights
- 5 plugins covering the security-observation lifecycle from session start through post-tool audit.
- 8 named algorithms (Aho-Corasick, Entropy, OWASP coverage, Action classifier, Config scanner, Phantom detector, Overflow guard, Threat modeler) — formal derivations in [docs/science/README.md](docs/science/README.md).
- 2,011 security patterns covering 98 CWEs.
- Action-guard hook: blocks dangerous commands before they run.
- Secret-scanner and vuln-detector hooks on post-tool events.
- Config-shield at session start: scans for repo-level attacks.
- Audit-trail output for forensic review.
- Zero runtime dependencies: bash + jq only.

[Unreleased]: https://github.com/enchanter-ai/hydra/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/enchanter-ai/hydra/releases/tag/v1.0.0
