---
name: license-awareness
description: >
  Scans the project's dep tree for license compatibility against an allow/deny policy.
  Use when the developer asks "what licenses are in here?" or before a release.
  Reports denied (GPL/AGPL/SSPL), warned (MPL/EPL/CDDL), and allowed (MIT/Apache/BSD/ISC)
  classifications. Do not use for license-text generation (see SBOM).
model: haiku
tools: [Read, Bash]
---

# license-awareness

## Preconditions

- Project root contains at least one of: `package.json`, `pyproject.toml`, `requirements.txt`.
- For npm scans: `npm install` has been run (node_modules/ present).
- For Python scans: `pip-licenses` is installed in the active environment (`pip install pip-licenses`).

## Inputs

- **Project path:** the developer's project root (default: cwd).
- **Policy file:** `${CLAUDE_PLUGIN_ROOT}/state/policy.json` — allow / deny / warn lists of SPDX IDs.

## Steps

1. Read `state/policy.json`. Confirm it parses as JSON with `allow`, `deny`, `warn` arrays.
2. Run the scanner:
   ```
   python ${CLAUDE_PLUGIN_ROOT}/scripts/license-scan.py <project-path>
   ```
3. The scanner shells out to `npx --yes license-checker --json` (npm) and/or `pip-licenses --format=json` (python).
4. Read its stderr lines. Each `[CRITICAL]` line names a denied dep; each `[MEDIUM]` line names a warned dep.
5. Summarize for the developer: count of deny/warn/allow, and the specific deny entries (pkg@ver license).

**Success criterion:** scanner exits 0; advisory lines emitted to stderr; summary surfaced to developer.

## Inputs the scanner accepts

- `<project>` — positional, defaults to cwd.
- `--policy <path>` — override the default policy.json.
- `--fail-on-deny` — exit non-zero if any DENY hits found. **PR/release context ONLY — never wire this into a hook** (advisory-only contract per `shared/foundations/conduct/hooks.md`).
- `--json` — emit structured summary on stdout.

## Outputs

- Stderr advisories (`[CRITICAL]` / `[MEDIUM]`).
- Optional JSON summary on stdout (`--json`).
- No file writes; the policy file is the only state.

## Handoff

- Release pipeline: invoke `python plugins/license-gate/scripts/license-scan.py --fail-on-deny .` as a step in the repo's `release.yml` to block releases on a DENY hit.
- SBOM emission: out of scope here. A future `sbom-emitter` plugin should consume the same `policy.json` for vendor matrix consistency.

## Failure modes

| Code | Scenario | Counter |
|------|----------|---------|
| F02  | Scanner reports a license verdict for a package whose actual license differs (e.g. dual-licensed misread) | The scanner splits SPDX expressions on OR/AND/WITH — a deny atom anywhere makes the dep DENY. If a developer disputes a verdict, surface the raw `license` string from `--json` output before defending the call. |
| F08  | Reaching for `grep` / manual inspection of node_modules instead of running the scanner | The scanner is the dedicated tool; node_modules is too large to grep usefully. |
| F14  | `policy.json` cites a retired SPDX ID (e.g. `GPL-3.0` vs `GPL-3.0-only`) | The default list is the short form; if developer's deps use the long form, advise updating policy.json or normalize at the scanner level. |
