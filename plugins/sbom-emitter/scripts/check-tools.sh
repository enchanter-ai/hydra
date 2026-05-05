#!/usr/bin/env bash
# check-tools.sh — Probe SBOM tooling availability. Advisory only.

trap 'exit 0' ERR INT TERM

if command -v npx >/dev/null 2>&1; then
  echo "[ok] npx: $(npx --version)" >&2
else
  echo "[missing] npx (install Node)" >&2
fi

if python -m cyclonedx_py --version >/dev/null 2>&1; then
  echo "[ok] cyclonedx-py: installed" >&2
else
  echo "[missing] cyclonedx-bom (pip install cyclonedx-bom)" >&2
fi

exit 0
