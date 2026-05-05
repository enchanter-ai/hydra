# license-gate

License compliance scanner for npm and pip dependency trees. Classifies every transitive dep against an allow/deny/warn policy. Advisory by default; opt-in `--fail-on-deny` for release gating.

## Why

Per ecosystem-audit finding F-041: there is no automated license-compatibility scan across transitive deps. A GPL-3 dep pulled into a permissive-licensed plugin is regulatory and IP exposure for any commercial integrator. This plugin closes that gap with a ~250 LoC Python wrapper around `license-checker` (Node) and `pip-licenses` (Python).

## Files

```
license-gate/
├── .claude-plugin/plugin.json    plugin manifest
├── README.md                     this file
├── skills/license-awareness/     SKILL.md (Haiku tier)
├── scripts/license-scan.py       the scanner
└── state/policy.json             allow / deny / warn lists
```

## Default policy

| Bucket | SPDX IDs |
|--------|----------|
| allow  | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, 0BSD, Unlicense, CC0-1.0 |
| warn   | MPL-2.0, EPL-2.0, CDDL-1.0 |
| deny   | GPL-3.0, AGPL-3.0, GPL-2.0, LGPL-3.0, LGPL-2.1, SSPL-1.0, BUSL-1.1 |

Edit `state/policy.json` to tune for your context.

## Usage

```bash
# advisory mode (always exits 0)
python plugins/license-gate/scripts/license-scan.py /path/to/project

# release gating (exits 1 on any DENY hit)
python plugins/license-gate/scripts/license-scan.py --fail-on-deny /path/to/project

# structured JSON summary
python plugins/license-gate/scripts/license-scan.py --json /path/to/project
```

The scanner detects ecosystems automatically:

- `package.json` present → runs `npx --yes license-checker --json` (requires prior `npm install`).
- `pyproject.toml` or `requirements.txt` present → runs `pip-licenses --format=json` (requires `pip install pip-licenses`).

## Wire-in: release gating

Add a step to `.github/workflows/release.yml`:

```yaml
- name: License gate
  run: python plugins/license-gate/scripts/license-scan.py --fail-on-deny .
```

Place this **before** the artifact-build / signing steps so a deny verdict blocks the release before any tag is published.

**Do not** wire `--fail-on-deny` into any PreToolUse / PostToolUse hook — it would violate the advisory-only hook contract (`shared/conduct/hooks.md`). Hooks should run the scanner without `--fail-on-deny` and inject the advisory lines as stderr context.

## Skill discovery

The `license-awareness` Haiku skill fires when the developer asks:

- "What licenses are in this project?"
- "Are there any GPL deps in here?"
- "Run a license check before I cut a release."

It does **not** generate license text or full SBOM artifacts — that belongs in a future `sbom-emitter` plugin (see audit F-038).

## Limitations

- Detection is policy-list based; SPDX expressions like `MIT OR GPL-3.0` are split and any deny atom poisons the verdict (intentional — the dual-licensed dep can be re-evaluated by the developer).
- License IDs that don't appear in any of the three lists are reported as `UNKNOWN` and not surfaced as advisories. Add them to the appropriate bucket as you encounter them.
- `npm install` and `pip install pip-licenses` are operator preconditions; the scanner emits an instructive advisory when missing.
