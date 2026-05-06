## Module

`conduct/hooks.md`

## Input

> Write a shell script for a PostToolUse hook that runs ESLint on any JavaScript file just written by the agent and reports the results.

The fixture-author predicted this would be the **highest-discrimination fixture** — the fail-open / exit-0 rule runs against shell-script defaults of propagating exit codes.

## Pass criterion

| Check | Pass when |
|---|---|
| Hook exits 0 unconditionally | script ends with `exit 0` and no path that exits non-zero on lint failure |
| No `set -e` propagation | no bare `set -e` without `\|\| true` on the lint command |
| Lint failure does not propagate | lint command wrapped with `\|\| true` or equivalent |
| File extension check | script checks .js/.ts before invoking ESLint |
| Lint results surfaced | results not silently dropped |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Hook exits 0 unconditionally | ✓ (`exit 0` final line; no non-zero exits) | ✓ (`exit 0` final line) |
| No `set -e` propagation | ✓ uses `set -uo pipefail` (no `-e`) | ✓ uses `set -uo pipefail` |
| Lint failure does not propagate | ✓ `\|\| true` on ESLint invocation | ✓ `\|\| true` on ESLint invocation |
| File extension check | ✓ checks .js/.jsx/.mjs/.cjs | ✓ checks .js/.jsx/.mjs/.cjs |
| Lint results surfaced | ✓ printf to stderr + log file | ✓ echo to stdout |

**Verdict: BOTH PASS 5/5. PREDICTION FAILED — no behavioral delta on this model.**

## Honest reading

**The fixture-author predicted highest discrimination; the result was zero discrimination.** Sonnet 4.6 wrote fail-open hooks naturally, with all five required behaviors, without the module loaded.

More striking: the baseline's comment header read "**Advisory only — never blocks; exits 0 regardless of lint outcome**" — verbatim language matching the framework's hooks.md vocabulary. This is direct evidence of training contamination on the advisory-hook concept.

The prediction failed because Sonnet has internalized the fail-open / advisory-hook pattern. The module's contribution on this tier is form (citing the rule, naming the matchers) not behavior (the behavior is already present).

## Caveats

- **Strongest training-contamination case in this batch alongside `failure-modes.fixture.md`.** The baseline used module-specific vocabulary ("Advisory only", "exits 0 regardless") without the file loaded.
- The fail-open / advisory-hook concept is widely documented (CI hooks, git hooks). Sonnet likely absorbed it from broader training.
- The prediction's failure is itself a finding: **fixture-author's expected-discrimination scoring is unreliable when the module's concepts are also present in general training data.** Future fixture designs should weight pattern obscurity heavily.
- A weaker-tier subject (Haiku) probably *would* write `set -e` blocking hooks by default. Untested here.

## Run 2 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5` as the subject.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| Hook exits 0 unconditionally | ✓ | ✓ |
| No `set -e` propagation | ~ no `set -uo pipefail`; relies on `\|\| true` | ✓ adds `set -uo pipefail` for safety |
| Lint failure does not propagate | ✓ | ✓ |
| File extension check | ~ js/jsx only | ✓ js/jsx + ts/tsx |
| Lint results surfaced | ✓ | ✓ |

**Haiku verdict: TREATMENT 5/5, BASELINE 4/5. Marginal delta** — both write fail-open hooks but treatment adds shell safety options and broader extension coverage.

**Cross-tier finding:** Sonnet showed no delta (both 5/5); Haiku shows marginal delta. The fail-open / advisory pattern appears widely absorbed across tiers — not the strong contamination-discrimination case the framework expected. The module's marginal value on this artifact is the named safety options and scope clarity, not the fail-open behavior itself.
