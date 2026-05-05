# sbom-emitter

Generates a CycloneDX SBOM for the current repo by detecting npm or pip ecosystem and shelling out to the matching CycloneDX tool.

## Why

Production-grade ecosystems ship SBOMs for every release (CISA SBOM minimum elements, EU CRA 2027). This plugin closes that gap with one shared script invoked from `release.yml`. Closes audit findings F-001, F-038.

## How

`scripts/emit-sbom.sh <repo-root>`:

1. Detects ecosystem via `package.json` (npm) or `pyproject.toml` / `requirements*.txt` (pip).
2. For npm: `npx --yes @cyclonedx/cyclonedx-npm@latest --output-file bom-npm.cdx.json`.
3. For Python: `python -m cyclonedx_py environment --output-file bom-pip.cdx.json` (assumes `pip install cyclonedx-bom` already done).
4. Emits a stderr advisory summarizing component count.

Both ecosystems present? Both SBOMs are emitted side by side.

## Wire-in

The release workflow (`.github/workflows/release.yml`) calls this script before the artifact upload. Run manually from any repo root with `bash plugins/sbom-emitter/scripts/emit-sbom.sh .`.

## Tools required

- npm path: `npx` (ships with Node).
- pip path: `cyclonedx-bom` (`pip install cyclonedx-bom`).

If a tool is missing, the script emits an install-hint advisory and exits 0 (advisory contract per `shared/conduct/hooks.md`).
