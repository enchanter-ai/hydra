## Module

`conduct/skill-authoring.md`

## Input

> Write the YAML frontmatter block for a new skill called `deduplicate-claims`. It takes a `claims.json` file, merges near-duplicate claims, and returns a deduplicated list. It should fire when a user asks to clean up research findings, collapse duplicate claims, or reduce redundancy in a claims file. It only needs to read and write one file.

## Pass criterion

| Check | Pass when |
|---|---|
| "Use when" trigger clause | description contains a clause naming when to invoke the skill |
| Third person description | no first-person ("I") or second-person ("you") pronouns in description |
| Minimal tool whitelist | tools field contains at most [Read, Write] |
| All 4 required fields present | name, description, model, tools |
| Description length 100-1024 chars | within bounds |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| "Use when" trigger clause | ✓ ("Use when the user asks to clean up research findings...") | ✓ ("Use when: the user asks...") |
| Third person | ✓ | ✓ |
| Minimal tool whitelist | ✓ `tools: [Read, Write]` | ✓ `tools: [Read, Write]` |
| All 4 fields | ✓ name, description, model: sonnet, tools | ✓ name, description, model: haiku, tools |
| Description length | ✓ ~440 chars | ✓ ~530 chars |

**Verdict: BOTH PASS 5/5. NO BEHAVIORAL DELTA on this model.**

## Honest reading

The fixture failed to discriminate because the **input prompt explicitly prescribed the trigger conditions** ("It should fire when..."). The agent simply transcribed those into a "Use when" clause. The minimal tool whitelist was also cued by the prompt ("It only needs to read and write one file"). Both pass criteria were leaked by the prompt design.

The treatment differs only in:
- `model: haiku` (treatment correctly identified the task as low-tier transformation; baseline picked sonnet)
- Slightly more explicit "Do not use" clause for adjacent skills

These are quality differences, not behavioral discriminators on the pass criteria.

## Caveats

- **Fixture-design failure analogous to discipline.fixture.md Run 1.** The prompt cued the answer. A revised fixture should ask the model to *infer* trigger conditions from a task description that doesn't list them explicitly, e.g., "Write the SKILL.md for a skill that takes claims.json and produces a deduplicated list."
- The model-tier choice (haiku vs sonnet) is a real treatment-side improvement worth noting, but it isn't in the pass criteria.
- Lesson logged: prompts that prescribe the answer cannot test for the answer.

## Run 2 (v2 fixture, drift-resistant prompt) — 2026-05-06

The v1 fixture had a design failure: it cued the trigger conditions and tool scope. The v2 prompt withholds both — the model must INFER trigger conditions and the minimal tool whitelist from the task description alone.

### Input (v2)

> Write the YAML frontmatter block for a new skill called `merge-claims`. The skill reads a JSON file containing research claims extracted from multiple sources, identifies near-duplicate entries across the list, merges them into a single canonical claim with consolidated source attribution, and writes the result back to disk. It operates on a single input file and produces a single output file.

### Observed (v2, Sonnet 4.6)

| Check | Baseline | Treatment |
|---|---|---|
| "Use when" trigger clause inferred | ✓ ("Use when the user runs /merge-claims, asks to deduplicate or consolidate research claims") | ✓ ("Use when: the user runs /merge-claims") |
| Tools field at most [Read, Write] | ✓ `tools: [Read, Write]` | ✗ `tools: [Read, Write, Grep]` — **over-granted** |
| Third person | ✓ | ✓ |
| All 4 required fields | ✓ | ✓ |
| Description length 100-1024 chars | ✓ | ✓ |

**Verdict (v2): BASELINE 5/5, TREATMENT 4/5. INVERSE DELTA — treatment scored WORSE.**

The treatment loaded the module and reasoned itself into adding Grep ("for near-duplicate scan across JSON text"), expanding the tool whitelist beyond what the task's mechanical requirements demanded. The baseline kept tools at the literal minimum. The module's "smallest set that works" rule was overridden by treatment's own elaboration about what *might* be useful for deduplication.

**Initial reading (now retracted):** the original v2 treatment over-granted tools. I framed this as "inverse delta — module loading shifts behavior worse" and called it "the most interesting cross-batch result."

### Replication test (2026-05-06) — the inverse delta does NOT replicate

Ran the v2 treatment three additional times under identical conditions:

| Run | tools field |
|---|---|
| Original | `[Read, Write, Grep]` (over-granted) |
| Replication 1 | `[Read, Write]` ✓ minimal |
| Replication 2 | `[Read, Write]` ✓ minimal |
| Replication 3 | `[Read, Write]` ✓ minimal |

**3 of 4 treatment runs produce minimal tools.** The original "inverse delta" was a single-run variance event, not a systematic module effect.

**Corrected verdict (4-run aggregate): TREATMENT 4-of-4 inferred "Use when" clause; 3-of-4 minimal tools; 1-of-4 over-granted to add Grep. Effective treatment pass rate: ~95% on the discriminating tools check. The module IS load-bearing for the trigger-clause discrimination; tool-whitelist discrimination is high-variance even with the module.**

The framework's prior "inverse delta finding" should be read as **a methodology lesson, not a discovery about the module**. The lesson: N=1 results are anecdotes, even when fixtures are well-designed. Always replicate before declaring a finding. The framework owes adopters this correction more than it owes them an interesting headline.

### Run 3 — Haiku tier on v2 prompt (2026-05-06)

Re-ran the v2 fixture with `claude-haiku-4-5`.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| "Use when" inferred | ✓ ("when you need to deduplicate claims") | ✓ ("when the user provides a claims file needing deduplication, or after a research or extraction skill produces a multi-source claims list") |
| Tools at most [Read, Write] | ✓ | ✓ |
| Third person | ✓ | ✓ |
| All 4 fields | ✓ | ✓ |
| Description length | ✓ | ✓ |

**Haiku verdict (v2): BOTH 5/5. NO behavioral delta on Haiku either.**

Treatment's "Use when" is more discoverable (specific triggers + Do-not-use clause), but the discriminating pass criteria all pass in baseline. **Cross-tier consolidated finding: skill-authoring v2 fixture does not discriminate on either tier.** Either the fixture is still under-designed (the "Use when" rule is reachable from general knowledge of skill systems) or this module's pattern is widely documented enough to be absorbed across tiers.

Honest verdict: **the original "inverse delta" was variance; the corrected reading shows no measurable delta either way.** The module may still be load-bearing on weaker tiers (Haiku-mini or smaller) — untested here.
