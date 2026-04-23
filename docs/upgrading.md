# Upgrading

Hydra follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Breaking changes only land on major version bumps (x.0.0).

## Between majors

Each major-to-major transition gets a dedicated section here with:

- A list of breaking changes.
- Specific migration steps users need to perform.
- A rollback path if the upgrade doesn't work.

Pattern-database updates (OWASP LLM Top 10 revisions, new CWE coverage, new CVE signatures) are **not** breaking changes — they ship in minor / patch releases. Changes to the hook contract, the action-guard severity scale, or the audit-trail schema **are** breaking.

## Current version

See [CHANGELOG.md](../CHANGELOG.md) for the current version and recent changes. As of this writing Hydra is on v1.0.0; no breaking-change migrations are documented yet. This page is a stub until the next major bump.
