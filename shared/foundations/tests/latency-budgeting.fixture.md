## Module

`conduct/latency-budgeting.md`

## Input

> Write the system prompt section for an orchestrator agent running a 5-step data-enrichment pipeline. Each step takes ~15 seconds. The pipeline runs interactively — a user is waiting. Include any latency management instructions.

The trap: 5 × 15 s = 75 s, which exceeds the module's 60 s interactive threshold. Treatment should flag the overrun and prescribe fan-out. Baseline likely won't apply the specific 60 s threshold.

## Pass criterion

| Check | Pass when |
|---|---|
| Numeric wall-clock cap stated | section contains a specific second value as latency threshold |
| Stop or fan out if exceeded | section directs to stop adding serial steps or fan out |
| Interactive threshold (60s) applied or 75s overrun flagged | uses 60 s OR explicitly notes 75 s exceeds the interactive threshold |
| Self-applying condition | gate written as instruction to orchestrator |
| Fallback behavior specified | names what the orchestrator does when the cap fires |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Numeric wall-clock cap | ✗ — mentions 75 s total and 20 s per-step in-progress signal, no overall CAP | ✓ — explicitly cites 60 s interactive cap multiple times |
| Stop or fan out if exceeded | ✗ — no language directing parallelization or termination on latency | ✓ — "STOP adding serial steps. Fan out remaining steps in parallel or report them as out-of-scope" |
| Threshold (60s) applied or overrun flagged | ✗ — acknowledges "approximately 75 seconds" but does not flag it as exceeding any threshold | ✓ — "5 serial steps × ~15 s each = ~75 s estimated total — this EXCEEDS the 60 s interactive cap" |
| Self-applying | ✓ (orchestrator-side rules) | ✓ ("Before starting EACH major step, run this two-line check") |
| Fallback specified | ~ specifies error stop, not latency-overrun stop | ✓ ("report them as out-of-scope with a note") |

**Verdict: TREATMENT 5/5, BASELINE 1-2/5. CLEAR BEHAVIORAL DELTA on the 60s threshold + fan-out language.**

## Honest reading

This is one of the **clearest behavioral deltas in the cross-batch test set.** Treatment named the specific 60 s interactive threshold, computed the 75 s overrun, and prescribed fan-out as the mitigation — all of which are module-specific. Baseline produced a thoughtful pipeline orchestrator prompt focused on user communication (announce/confirm each step) but applied no latency cap and no overrun detection.

The discriminating mechanism: **the 60 s interactive threshold is a specific numeric value in the module that the agent cannot infer from general "be responsive to users" reasoning.** Either the agent has read the module (treatment) or it hasn't (baseline) — and the difference shows up cleanly in the output.

This validates the cross-fixture hypothesis: **modules prescribing specific structural artifacts (numeric thresholds, named gates, fan-out language) discriminate; modules prescribing general reasoning practices (be careful, be honest) do not.**

## Caveats

- Single-tier proof. A weaker tier might have an even larger delta (would not even produce the orchestrator scaffolding the baseline did).
- The treatment's dependency on the specific 60 s value means the fixture won't survive a module revision that changes the threshold without simultaneously updating the fixture.
- The fixture is well-shaped because the user's pipeline (5 × 15 s) sits *above* the module's threshold — if the pipeline had been 3 × 15 s = 45 s, both runs would pass and the discrimination would vanish.

## Replication test (2026-05-06) — 2 additional runs

| Run | Baseline names 60s cap? | Treatment names 60s cap + flags 75s overrun + prescribes fan-out? |
|---|---|---|
| Original (2026-05-05) | ✗ | ✓ all three |
| Replication 1 | ✗ | ✓ all three + retry budget + latency log |
| Replication 2 | ✗ | ✓ all three + retry budget + latency log |

**3-run aggregate: 3 of 3 treatments name the 60s interactive cap, flag the 75s overrun, and prescribe parallelization; 3 of 3 baselines do none of these.** Strong delta replicates cleanly. Latency-budgeting.md is one of the framework's most reliably load-bearing modules on Sonnet.
