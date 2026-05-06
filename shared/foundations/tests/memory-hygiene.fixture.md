## Module

`conduct/memory-hygiene.md`

## Input

> Working memory contains 24 entries (excerpt: 6 entries shown). For each, give a verdict (keep / write-to-state / discard) and a one-sentence reason. Entries: (1) snake_case schema confirmed, (2) draft note about camelCase rejected, (3) batch_insert deprecated, (4) scratch token count, (5) open question about parallel writes, (6) 2-space indentation confirmed.

## Pass criterion

| Check | Pass when |
|---|---|
| Entry 2 (draft note) discarded | verdict for entry 2 is `discard` |
| Entry 4 (scratch) discarded | verdict for entry 4 is `discard` |
| ≥2 confirmed entries write-to-state | ≥2 of entries 1, 3, 6 have verdict `write-to-state` |
| Entry 5 (open question) not discarded | entry 5 verdict is `keep` or `write-to-state` |
| Prune trigger acknowledged | response mentions 24>20 threshold or prune-pass language |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Entry 2 discarded | ✓ | ✓ |
| Entry 4 discarded | ✓ | ✓ |
| ≥2 confirmed write-to-state | ✓ (1, 3, 6 all write-to-state) | ~ borderline (1, 3 write-to-state; 6 is "keep" with rationale "directly relevant to ongoing work") |
| Entry 5 not discarded | ✓ (kept) | ✓ (write-to-state) |
| Prune trigger acknowledged | ✗ no mention of 24>20 threshold | ✗ no explicit threshold mention |

**Verdict: BASELINE 4/5, TREATMENT 4/5. NO BEHAVIORAL DELTA on this model.**

## Honest reading

Both runs correctly discarded the superseded draft (entry 2) and the scratch (entry 4) — these are intuitively correct discards regardless of the module. Both kept or wrote-to-state the confirmed facts and the open question.

The discriminating check was supposed to be the **prune trigger acknowledgment** (24 > 20 entries should trigger a prune pass per the module). Neither run named this threshold explicitly. The module's specific numeric trigger didn't propagate into either response.

The treatment differs in a subtle way: it kept entry 6 (2-space indentation) in working memory rather than writing to state, with the rationale that it's "directly relevant to ongoing code-generation work." This is actually a **closer reading** of the module's three-test relevance gate — the baseline wrote it to state on the more conservative grounds that it's a "stable convention." Both readings are defensible.

## Caveats

- The numeric prune trigger (20 entries) is module-specific but didn't appear in either response — the discriminating signal failed to fire.
- Both runs reasoned correctly about superseded vs. confirmed entries; the All-Add anti-pattern is widely understood.
- A revised fixture should *test* the trigger more directly — e.g., "your working memory has N entries; should you prune?" rather than asking for per-entry verdicts.

## Run 2 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5` as the subject. Run-A baseline output not preserved verbatim, but the Haiku self-note captures the behavioral delta:

| Behavior | Haiku Baseline | Haiku Treatment |
|---|---|---|
| Entry 2 (rejected camelCase draft) | write-to-state | **discard** (stricter relevance gate via three-test framework) |
| Entry 4 (scratch token count) | discard ✓ | discard ✓ |
| Entry 6 (2-space indent) | write-to-state | **discard** (treatment: "redundant confirmation; not architectural input") |
| Entry 5 (open question) | keep | write-to-state ✓ |

**Haiku verdict: behavioral delta** — treatment applies the three-test gate explicitly (direct relevance / dedup check / changes-next-action) and downgrades 2 of 6 entries from write-to-state to discard.

**Cross-tier:** Sonnet treatment kept entry 6 in working memory; Haiku treatment discards it. The module's stricter gate fires on Haiku because Haiku without the module defaults to "keep more, just in case" — exactly the All-Add anti-pattern the module is designed to prevent.
