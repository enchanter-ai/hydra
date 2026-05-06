## Module

`conduct/precedent.md`

## Input

> You just tried to run `python scripts/score.py --weights=strict` and it failed with: 'Error: unrecognized argument --weights'. You fixed it by switching to `python scripts/score.py --weight-mode strict`. Write the precedent log entry for this failure so it can be consulted in future sessions.

## Pass criterion

| Check | Pass when |
|---|---|
| Verbatim failing command | entry contains literal `python scripts/score.py --weights=strict` |
| Verbatim working command | entry contains literal `python scripts/score.py --weight-mode strict` |
| Signal line is actionable | Signal field names a concrete trigger condition, not a generic warning |
| Tags field present | `Tags:` line with ≥2 lowercase comma-separated single-word tags |
| Date header present | entry begins with markdown heading including a YYYY-MM-DD date |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Verbatim failing command | ✓ | ✓ |
| Verbatim working command | ✓ | ✓ |
| Signal line is actionable | ✓ ("before passing `--weights` to score.py, check that the flag is `--weight-mode`") | ✓ ("next time you invoke `score.py`, grep its `--help` output or argument parser for `weight` before reaching for `--weights`") |
| Tags field present | ✓ (`bash, python, argparse, score, flags`) | ✓ (`bash, python, flags, score, obsolete-flag`) |
| Date header present | ✓ (`## 2026-05-05 — Wrong flag name for score.py weight mode`) | ✓ (`## 2026-05-05 — Obsolete flag --weights in score.py`) |

**Verdict: BOTH PASS 5/5. NO BEHAVIORAL DELTA on this model.**

## Honest reading

Both runs produced near-identical entries with all fields. The "precedent log entry with verbatim commands and actionable signal" format is widely documented in operational engineering practice (postmortems, runbooks, incident logs) — the model produces this shape from training, not from this specific module.

The treatment slightly improved the Signal line by suggesting `--help` inspection (more concrete) versus the baseline's "check that the flag is `--weight-mode`" (assumes the answer). Marginal improvement, not a behavioral delta on the pass criteria.

## Caveats

- Training contamination on the structural format is high — operational log entries are a well-documented pattern.
- The discriminating power on Sonnet is exhausted; a weaker tier (Haiku) might produce diary-style entries without the structured fields. Untested here.
- The fixture-author's prior-batch caveat applies: this fixture is a regression test on Sonnet, not an impact measurement.

## Run 2 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5` as the subject.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| Verbatim failing command | ✓ | ✓ |
| Verbatim working command | ✓ | ✓ |
| Signal line is actionable | ~ generic ("check the script's help output or recent changes") | ✓ specific ("if score.py fails on `--weights`, try `--weight-mode`") |
| Tags field present | ✓ ("python, cli, flags") | ✓ ("python, score, cli-drift") |
| Date header present | ✓ | ✓ |

**Haiku verdict: BOTH 5/5. MARGINAL delta** — treatment produces sharper signal and more specific tags, but baseline already passes all five checks.

**Cross-tier:** Operational log entry format is widely documented across tiers; both Sonnet and Haiku produce it without the module. The module's marginal value is signal-line specificity and tag granularity, not the basic structural format.
