## Module

`conduct/delegation.md`

## Input

> Write a delegation prompt I can paste directly into a subagent task to have it investigate why the Zelkrin build pipeline fails on the `--emit-manifest` flag. The subagent has Read, Grep, and Glob tools.

## Pass criterion

| Check | Pass when |
|---|---|
| Structured return clause | prompt ends with explicit output format (typed schema or labeled blocks) |
| Scope fence | prompt names ≥1 thing the subagent must NOT do |
| Context briefing | prompt states what is already ruled out / what is not yet known |
| Word cap | structured return clause includes numeric output bound |
| All three clauses structurally distinct | three clauses recognizable as separate sections |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Structured return clause | ✓ (`ROOT_CAUSE / EVIDENCE / DEAD_ENDS / OPEN_QUESTIONS` block) | ✓ (`SUMMARY / FINDINGS / GAPS / RECOMMENDED NEXT STEP` block) |
| Scope fence | ✓ ("Do not write or edit", "Read-only") | ✓ ("Do NOT fix", "Do NOT edit", "Do NOT spawn sub-subagents", "Do NOT run shell") |
| Context briefing | ✓ ("Nothing has been ruled out yet") | ✓ ("Nothing has been ruled out yet") |
| Word cap | ✓ ("Under 400 words total") | ✓ ("Total response under 400 words") |
| Three clauses distinct | ✓ (## Context / ## Your task / ## Stop conditions / ## Return format) | ✓ (Context briefing / Tools / Scope fence / Steps / Structured return) |

**Verdict: BOTH PASS 5/5. NO BEHAVIORAL DELTA on this model.**

## Honest reading

Sonnet 4.6 produces well-structured delegation prompts with all three non-negotiable clauses by default — the structured return clause, scope fence, and context briefing all appeared in the baseline without any module exposure.

The treatment differs in *form*: it cites the module's three clauses by name, lists the right-tool-first-try rule explicitly, and structures the prompt as labeled sections matching delegation.md's vocabulary. Baseline produces equivalent content under different headings (`## Context`, `## Your task`, `## Stop conditions`, `## Return format`).

The pattern of "delegation prompt with structured return + scope fence + briefing" is widely documented outside this framework — likely contamination from general agent-design literature.

## Caveats

- Likely training contamination — structured-return-with-scope-fence is a common delegation pattern.
- The fixture's value on Sonnet is as a regression test (does loading the module break the structure?) rather than as an impact measurement.
- A weaker tier (Haiku) might produce loose delegation prompts without these clauses; the module would discriminate there. Untested here.

## Run 2 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5` as the subject.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| Structured return clause | ✓ | ✓ |
| Scope fence | ✓ | ✓ |
| Context briefing | ~ thin ("This is a Zelkrin build system issue") | ✓ explicit "Already ruled out / Need to focus on" structure |
| Word cap | ✓ ("under 300 words") | ✓ |
| Three clauses structurally distinct | ~ blended in prose | ✓ explicit `**Context briefing**`, `**Scope fence**`, `**Structured return clause**` labels |

**Haiku verdict: TREATMENT 5/5, BASELINE 4/5. Borderline-clear delta** — treatment uses module-vocabulary section labels; baseline produces equivalent content in less structured prose.

**Cross-tier:** Sonnet showed no delta; Haiku shows borderline delta on labeling rigor. The module's three-clause naming convention is what discriminates on Haiku.
