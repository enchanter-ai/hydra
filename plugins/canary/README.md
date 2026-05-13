# canary

Advisory prompt-injection canary harness. Seeds a per-session high-entropy token into a stderr advisory before every `WebFetch`, then scans every subsequent tool input/output for the token's appearance. **A hit means an indirect prompt injection succeeded** — attacker-controlled text routed the canary back through the agent into another tool call. **Always exits 0; never blocks.**

## Why

Wixie's `deep-research`, Hydra's `vuln-detector`, and any plugin pulling `WebFetch` content all funnel attacker-controlled text into Opus/Sonnet contexts. Without a canary, a successful indirect injection is invisible to operators (per ecosystem-audit finding **F-004**). Existing prompt-injection coverage is detection-only at the static-pattern layer (hidden Unicode, regex on payloads); this plugin closes the runtime-leakage gap (per finding **F-044**, gap-to-prod ~40% → continuous canary harness).

## Behavior

| Phase | Hook | What it does |
|---|---|---|
| Seed | PreToolUse(WebFetch) | Generates `CANARY-<8-char-base32>` per session, persists to `state/active-canaries.json` (atomic write), emits stderr advisory with the tripwire `<system>` directive. |
| Scan | PostToolUse(*) | Reads tool_input + tool_response, greps for any active canary, emits stderr `HIT:` advisory and appends a finding to `state/hits.ndjson` (cross-platform locked append per templates.md § G). |

Both phases exit 0 unconditionally and skip cleanly inside subagents (`CLAUDE_SUBAGENT` recursion guard).

## Pre-filter

The scan hook fires on every PostToolUse but short-circuits before spinning up Python when `state/active-canaries.json` is empty (no `WebFetch` has run this session, so nothing can leak).

## Files

```
hydra/plugins/canary/
├── .claude-plugin/plugin.json
├── README.md                              this file
├── skills/canary-awareness/SKILL.md       Haiku skill: interprets hits
├── hooks/hooks.json                       registers two hooks
├── hooks/pretooluse-webfetch.sh           seed phase
├── hooks/posttooluse-scan.sh              scan phase (with active-canary pre-filter)
├── scripts/canary-seed.py                 generate token, atomic-write state, stderr advisory
├── scripts/canary-scan.py                 grep for active tokens, stderr advisory + locked NDJSON append
└── state/active-canaries.json             per-session tokens
    state/hits.ndjson                      append-only finding log (created on first hit)
```

## Token format

`CANARY-<8-char-base32>` — 5 random bytes via `secrets.token_bytes`, encoded with no padding. High-entropy enough that accidental appearance in attacker-controlled text is negligible.

## Honest limits

1. **Detection, not prevention.** A hit fires after the leak — the agent already ingested the attacker's payload. The advisory tells you to rotate and review.
2. **Per-session scope.** Tokens key off `session_id` from the hook payload (or `"default"` if absent). Cross-session correlation is not in scope.
3. **No automatic rotation.** Manual: delete the session's entry from `state/active-canaries.json`; next `WebFetch` reseeds.
4. **Subagent recursion guard is environment-based.** Relies on the harness setting `CLAUDE_SUBAGENT` for spawned subagents. If the harness does not set it, scan still fires (advisory only — no harm beyond duplicate logs).

## Hook contract

- **Always exit 0.** Per `wixie/../foundations/packages/core/conduct/hooks.md`.
- **Inject, never deny.** Output goes to stderr (visible to Claude); never to stdout.
- **Fail-open.** Missing `python3`, malformed JSON, I/O errors — all silently skipped. The hook never breaks the underlying tool call.

## Skill

`/skill canary-awareness` (Haiku) — reads `state/active-canaries.json` + `state/hits.ndjson`, reports session status, recommends rotation after a hit.

## CI gate (F-004 closure)

Beyond the runtime advisory hook, a **CI gate** verifies the detection
surface against a fixture set on every PR and every push to `main`.

| Surface | Mode | Source of truth |
|---|---|---|
| Runtime hook (`posttooluse-scan.sh`) | **Advisory only — always exit 0** | `../foundations/packages/core/conduct/hooks.md` |
| CI gate (`ci-canary-gate.py`) | **Blocking — non-zero on miss** | `.github/workflows/canary-ci.yml` |

The CI gate loads every JSON fixture under `fixtures/injection/` (10
indirect-injection cases drawn from OWASP LLM01:2025 — fake `<system>`
tags, markdown-quote impersonation, hidden HTML comments, tool-result
spoofing, zero-width unicode, base64 smuggle, citation impersonation,
roleplay jailbreaks, etc.). For each fixture it:

1. Seeds a temporary `state/active-canaries.json` with the fixture's
   `canary_token`.
2. Builds a synthetic PostToolUse payload from `fixture.input` +
   `fixture.output`.
3. Pipes it into `scripts/canary-scan.py`.
4. Asserts the scanner emits `HIT: canary <TOKEN>` on stderr **and**
   appends a finding to `state/hits.ndjson`.
5. Restores the original state files before exit.

Any fixture missing a detection fails the workflow check. **The runtime
hook contract is unchanged** — it still exits 0 unconditionally. The CI
gate verifies the *detection* surface; the runtime surface stays advisory
per `../foundations/packages/core/conduct/hooks.md`.

This closes ecosystem-audit finding **F-004** (advisory → CI-blocked
detection of indirect prompt-injection canary leakage).

Run locally:

```bash
python plugins/canary/scripts/ci-canary-gate.py
```

## Relationship to other Hydra plugins

- `canary` (this) — runtime detection of successful indirect injection.
- `vuln-detector` — static pattern matching against known attack payloads.
- `audit-trail` — captures tool use; canary findings are a HIGH-severity input to it once the route is wired.
- `secret-scanner` — different threat (credential leak) but symmetric architecture.

Removing this plugin leaves the indirect-injection runtime slice uncovered. It is advisory and not load-bearing.

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, web-fetch, precedent.
