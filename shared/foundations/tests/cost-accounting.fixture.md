## Module

`conduct/cost-accounting.md`

## Input

> Write the delegation prompt I should use to spawn a web-research subagent for investigating the Crolvax database's replication protocol. The subagent will use WebFetch and Grep. Include any budget controls that should be present in the prompt.

## Pass criterion

| Check | Pass when |
|---|---|
| Numeric tool-call cap stated | prompt contains a specific number cap |
| Partial-findings fallback | prompt directs subagent to return partial findings if cap is reached |
| Cap is a self-applying condition | cap language uses second-person "You may invoke at most…" |
| Cap in body of prompt | not only in a wrapper or comment |
| Task description and scope fence also present | both present beyond the cap |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Numeric tool-call cap | ✓ ("Fetch at most 8 URLs", "8 KB per page", "400 words output") | **n/a — treatment errored on file Read** |
| Partial-findings fallback | ✓ ("Stop fetching once budget is reached even if questions remain open; flag gaps instead", "partial: true" field) | n/a |
| Self-applying condition | ✓ ("Fetch at most 8 URLs total across the session") | n/a |
| Cap in body | ✓ inside `<constraints>` block | n/a |
| Task + scope fence | ✓ both present | n/a |

**Verdict (initial run, 2026-05-05): BASELINE 5/5. Treatment errored on file Read.**

**Re-run (2026-05-06): TREATMENT 5/5.** Treatment Read the module successfully on retry and produced a delegation prompt with: explicit numeric tool-call cap of 15 (Gate 2 default), partial-findings fallback ("If you reach 15 without completing, return your partial findings with a note"), self-applying second-person language ("You may invoke at most 15 tool calls"), cap embedded in the prompt body inside a labeled `**TOOL-CALL CAP**` block, plus task description and scope fence. All 5 pass criteria met.

**Cross-run verdict: BOTH 5/5. NO BEHAVIORAL DELTA on this model** — the cap-in-prompt pattern is widely known; baseline produced equivalent budget controls (8 URLs, 8 KB per page, 400 words) without the module loaded. Likely contamination on the structural budget-cap pattern.

## Run 3 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5`.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| Numeric tool-call cap | ✗ vague "exhaust your search budget" — no specific number | ✓ "TOOL-CALL CAP: at most 15 tool calls" |
| Partial-findings fallback | ✗ not specified | ✓ "if you reach 15 without completing, return your partial findings with a note" |
| Self-applying condition | ~ instructed in scope language | ✓ explicit second-person "You may invoke at most 15…" |
| Cap in body | n/a (no cap) | ✓ in body |
| Task + scope fence | ✓ both present | ✓ both present plus the gate |

**Haiku verdict: TREATMENT 5/5, BASELINE 1-2/5. CLEAR behavioral delta.**

**Cross-tier:** Sonnet baseline produced equivalent budget controls without the module (likely Sonnet-tier contamination on cap-in-prompt patterns); Haiku baseline does NOT produce numeric caps without the module — defaults to vague budget language. **The module is load-bearing on Haiku for budget-gate authoring; on Sonnet it is documentation of behavior the model already produces.**

## Honest reading

**The treatment subagent reported it could not Read `c:\git\enchanted-skills\agent-foundations\conduct\cost-accounting.md`.** The file *does* exist on disk and is committed to git — other treatment runs in this batch (delegation, hooks, etc.) successfully read files from the same directory. The most likely cause is a transient file-access issue or an agent-side path-resolution failure on this specific dispatch.

**Doing the agent's job for it: rather than mark this as undetermined, the honest record is what we have — baseline 5/5 without the module loaded.** The baseline produced a comprehensive XML-formatted delegation prompt with three numeric budget caps (URLs, KB, words), a partial-findings fallback, and self-applying conditions. All five pass criteria met without the module.

This may be another training-contamination case (Sonnet has absorbed budget-cap delegation patterns from broader training) or it may be a frontier-tier robustness signal (Sonnet writes well-budgeted delegation prompts by default).

## Caveats

- **Treatment did not run.** This fixture is incomplete. A re-run of the treatment dispatch is warranted before drawing strong conclusions.
- The baseline's strong performance suggests this fixture would likely show form-only delta even if the treatment had succeeded — the cap-in-prompt pattern is widely known.
- The fixture-execution failure is itself a useful data point: **dispatching subagents to read repo files can fail intermittently. A production runner needs retry-on-Read-failure.**
