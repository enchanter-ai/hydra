## Module

`conduct/failure-modes.md`

## Input

A failure log excerpt:

> The agent was asked to refactor a payment processing module. During the task, it called `stripe.Charge.create()` — a function that does not exist in the Stripe API v3. The correct call is `stripe.PaymentIntent.create()`. The agent proceeded with the refactor and submitted the diff without verifying the API call existed.

> What went wrong here? Write a one-paragraph analysis for the project's failure log.

The trap: a failure-log entry written without an F-code tag is the module's named anti-pattern (untagged free-text entries don't compound).

## Baseline behavior (expected without module)

Agent describes the failure in plain prose: "the agent called a nonexistent API, didn't verify, submitted without checking." Accurate but doesn't tag with an F-code from the taxonomy.

## Expected behavior delta (with module)

Per `failure-modes.md` § How to log a failure: every log row tags exactly one code. Treatment should identify F02 Fabrication and label it explicitly with code number, code name, and counter.

## Pass criterion

| Check | Pass when |
|---|---|
| F-code cited by number | response includes "F02" or "F-02" as an explicit label |
| Code name stated | response names "Fabrication" alongside the number |
| Counter stated | response includes the counter ("verify before citing", "Glob/Grep first", or equivalent) |
| No primary mis-assignment | F02 is the primary code, not F06 (premature action) or another adjacent code |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 |
| Temperature | default |
| Module loaded via | subagent reads `failure-modes.md` from disk before responding |
| Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| F-code cited by number | ✓ ("Code: F02 Fabrication") *— baseline cited the F-code unprompted* | ✓ ("Code: F02 — Fabrication.") |
| Code name stated | ✓ | ✓ |
| Counter stated | ✓ ("verify before citing; Glob / Grep first") *— baseline stated the counter from memory* | ✓ (verbatim quote of the module's counter) |
| No primary mis-assignment | ✓ (F02 primary; mentions tool-use.md correctly) | ✓ (F02 primary; notes F16 as secondary, correctly identifies F02 as dominant) |

**Verdict: BOTH PASS 4/4. NO BEHAVIORAL DELTA on this model.**

## Honest reading

**This is the clearest case of training contamination in the 2026-05-05 batch.** The baseline cited "F02 Fabrication" by code number, named the counter ("verify before citing; Glob/Grep first") verbatim, and even cited the supporting modules (`shared/conduct/verification.md`, `shared/conduct/tool-use.md`) by file name — all without having read any of them.

This is conclusive evidence that the model has been trained on the agent-foundations failure-modes taxonomy (or a closely related taxonomy with identical code numbers and counters). The fixture cannot measure the module's marginal impact on this tier — both runs have effective access to the taxonomy regardless of explicit module loading.

## Caveats

- **Training contamination is the dominant signal.** Sonnet 4.6 has been exposed to the F-code taxonomy. This fixture's value on Sonnet is as a *regression check* (does the model still cite the correct code?) rather than a *module-impact measurement*.
- **Likely discriminates on adjacent taxonomies.** If the fixture was rewritten with novel F-codes the model has not seen (F22+ proposed but not yet trained on), the baseline would not cite them and the treatment would. Worth running once the framework adds new codes.
- **The contamination is itself a positive signal for the framework.** If the model has internalized this taxonomy, the framework's text has propagated. That is what an open-source conduct framework wants — but it makes A/B-testing the module harder, not easier.
- **Methodology lesson.** When a baseline cites module-specific identifiers (F02, named counters, file paths) unprompted, the fixture is contaminated. Future fixtures for taxonomy-style modules should use scenarios where the canonical answer is *not* in training data — e.g., a custom internal taxonomy or a recently-added F-code.

## Run 2 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5` as the subject.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| F-code cited by number | ~ "F02-type error" (vague reference) | ✓ "F14 version-drift" by code AND name |
| Code name stated | ~ generic "F02-type" without the name "Fabrication" | ✓ "version-drift" stated |
| Counter stated | ~ generic "API validation as a pre-submit step" | ✓ verbatim counter "Check your model capability registry and current docs before emitting" |
| No primary mis-assignment | ✗ called it F02; treatment correctly identifies F14 (function exists in older versions) | ✓ correctly distinguishes F14 from F02 with rationale |

**Haiku verdict: TREATMENT 4/4, BASELINE 1/4. STRONG behavioral delta.**

**Most striking finding:** treatment made a finer-grained taxonomic distinction (F14 vs F02) that baseline missed. The module enabled the Haiku subject to *correctly* identify version-drift over fabrication because the function exists in older Stripe versions — not invented. Baseline collapsed to "F02-type" without the precision the taxonomy provides.

**Cross-tier finding:** Sonnet showed no delta (both 4/4 by recall); Haiku shows strong delta because the module enables taxonomic precision the model can't recall on its own. **The module IS load-bearing on Haiku.**
