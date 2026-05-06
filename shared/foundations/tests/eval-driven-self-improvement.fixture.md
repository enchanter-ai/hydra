## Module

`conduct/eval-driven-self-improvement.md`

## Input

> The Grindel summarization agent fetched 4 unrequested competitor pricing pages, doubling the session cost. The user manually scope-corrected the agent. Write the complete improvement artifact for this failure — everything needed to prevent recurrence.

## Pass criterion

| Check | Pass when |
|---|---|
| F-code assigned | artifact contains an F-code tag (e.g., F04) |
| Counter is concrete delegation-prompt sentence | counter is a clause one could paste directly into a subagent prompt |
| Regression case present with pass condition | block with RC-ID format and checkable pass condition |
| Pass condition is checkable | names a specific observable absence/presence |
| Counter and regression case structurally distinct | separate labeled sections, not fused |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| F-code assigned | ✓ "F04" | ✓ "F04" |
| Counter is concrete delegation-prompt sentence | ✓ ("Every summarization-agent prompt must include an explicit scope fence naming what is out of scope (example: 'Do not fetch competitor pages…')") | ✓ ("Retrieve information only about the specific subject named in the task goal. Do NOT fetch competitor pages, pricing comparisons…") — quoted as paste-ready |
| Regression case with RC-ID + pass condition | ✗ — no RC-ID structure; produces a single JSON artifact with code/cause/counter/signal/tags but no separate regression case | ✓ — explicit `RC-2026-05-05-1` block with input, expected behavior, observed failure, counter applied, **pass condition** |
| Pass condition is checkable | ~ implicit signal "stop, report, ask" but not a regression test pass condition | ✓ ("Agent completes the summarization task without fetching any competitor or pricing URLs. Session cost is within ±20% of the declared budget. No user scope-correction is needed during the session.") |
| Counter and regression case distinct | ✗ fused into one JSON artifact | ✓ explicit `### Counter` and `### Regression case` sections |

**Verdict: TREATMENT 5/5, BASELINE 2-3/5. CLEAR BEHAVIORAL DELTA on the regression-case structure.**

## Honest reading

The discriminator is the **RC-ID regression case structure with a checkable pass condition**. Both runs assigned F04 and produced concrete counters. Only treatment produced a separate regression case block with a measurable pass condition (no competitor URLs fetched, ±20% budget, no scope correction).

The baseline produced a high-quality JSON artifact with all the *information* — code, cause, counter, signal, tags, scope, evidence — but as a single fused entry. The module mandates separating the *counter* (forward-looking rule) from the *regression case* (backward-looking checkable test). That structural separation is what discriminates.

This is the second clearest delta in the 11-fixture batch (after `latency-budgeting.fixture.md`), validating the same hypothesis: **structural artifacts (RC-ID + checkable pass condition + section separation) discriminate where reasoning practices contaminate.**

## Caveats

- F04 tagging is contaminated (the F-code taxonomy is in training data); this check would pass even without the module.
- The counter quality differs in form: treatment produced a longer paste-ready prompt clause; baseline produced equivalent semantic content but as part of a JSON field. Both are usable.
- The discriminating check (regression case with RC-ID) requires the model to know the module's specific structural convention. Without it, even careful agents produce post-mortem-style artifacts rather than runnable regression cases.

## Replication test (2026-05-06) — 2 additional runs

| Run | Baseline has RC-ID + checkable pass condition? | Treatment has RC-ID + checkable pass condition + session eval + promote trigger? |
|---|---|---|
| Original (2026-05-05) | ✗ | ✓ |
| Replication 1 | ✗ | ✓ — `RC-2026-05-05-1` with pass condition "zero URLs from competitor domains; cost within 10% of baseline" + session eval entry + re-eval instruction + promotion threshold |
| Replication 2 | ✗ | ✓ — `RC-2026-05-05-1` with pass condition "Agent completes the summarization task without fetching any URL not present in the input source list. Session token cost stays within ±20% of the established baseline." + session eval entry + re-eval instruction + promote trigger |

**3-run aggregate: 3 of 3 treatments produce RC-ID regression cases with checkable pass conditions; 3 of 3 baselines produce learning-log entries without regression structure.** Strong delta replicates cleanly. The RC-ID format + checkable pass condition is a structural artifact the module reliably produces and the baseline reliably misses.
