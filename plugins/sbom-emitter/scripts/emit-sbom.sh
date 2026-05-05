#!/usr/bin/env bash
# emit-sbom.sh — Generate CycloneDX SBOM for the given repo root.
# Advisory contract: always exit 0 per shared/conduct/hooks.md.

trap 'exit 0' ERR INT TERM

REPO_ROOT="${1:-.}"
cd "$REPO_ROOT" || exit 0

EMITTED=0

# npm ecosystem
if [ -f "package.json" ]; then
  if command -v npx >/dev/null 2>&1; then
    OUT="bom-npm.cdx.json"
    if npx --yes @cyclonedx/cyclonedx-npm@latest --output-file "$OUT" 2>/dev/null; then
      COMPONENTS=$(grep -c '"bom-ref"' "$OUT" 2>/dev/null || echo "?")
      echo "=== sbom-emitter (advisory) ===" >&2
      echo "npm: $OUT written, ~$COMPONENTS components" >&2
      EMITTED=1
    fi
  else
    echo "=== sbom-emitter (advisory) ===" >&2
    echo "npm path: npx not found. Install Node to enable." >&2
  fi
fi

# Python ecosystem
if [ -f "pyproject.toml" ] || ls requirements*.txt 2>/dev/null | grep -q .; then
  if python -m cyclonedx_py --version >/dev/null 2>&1; then
    OUT="bom-pip.cdx.json"
    if python -m cyclonedx_py environment --output-file "$OUT" 2>/dev/null; then
      COMPONENTS=$(grep -c '"bom-ref"' "$OUT" 2>/dev/null || echo "?")
      echo "=== sbom-emitter (advisory) ===" >&2
      echo "pip: $OUT written, ~$COMPONENTS components" >&2
      EMITTED=1
    fi
  else
    echo "=== sbom-emitter (advisory) ===" >&2
    echo "pip path: cyclonedx-bom not installed (pip install cyclonedx-bom)." >&2
  fi
fi

if [ "$EMITTED" -eq 0 ]; then
  echo "=== sbom-emitter (advisory) ===" >&2
  echo "No supported ecosystem detected (package.json / pyproject.toml / requirements.txt)." >&2
fi

exit 0
