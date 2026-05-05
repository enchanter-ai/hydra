---
name: sbom-awareness
description: >
  Generates a CycloneDX SBOM (bom-npm.cdx.json or bom-pip.cdx.json) for the current repo
  by detecting npm or pip ecosystem and shelling out to the matching tool. Use when the
  developer asks for an SBOM, runs the release workflow, or needs to satisfy CISA SBOM /
  EU CRA requirements. Auto-fires on tag push via release.yml. Do not use for license
  compliance scanning (see license-gate).
allowed-tools: [Read, Bash]
---

# sbom-awareness

## Preconditions

- Repo has either `package.json` (npm) OR `pyproject.toml` / `requirements*.txt` (pip).
- For npm: `npx` available.
- For pip: `cyclonedx-bom` installed (`pip install cyclonedx-bom`).

## Steps

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-tools.sh` to verify tooling.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/emit-sbom.sh <repo-root>`.
3. Confirm `bom-npm.cdx.json` and/or `bom-pip.cdx.json` exist at repo root.
4. Report component count to the developer.

## Failure modes

- Tool missing → advisory with install hint, exit 0.
- Unsupported ecosystem (no manifests detected) → advisory, exit 0.
- Both ecosystems present → emit one SBOM per ecosystem with suffixes.
