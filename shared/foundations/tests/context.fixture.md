## Module

`conduct/context.md`

## Input

> Design a 6-section agent system prompt for the 'Vorrax' compliance-scanning workflow. The sections are: (1) Role & persona, (2) Reference corpus excerpt (12 pages of regulation text), (3) Task description, (4) Output format, (5) Examples bank (8 worked examples), (6) Hard gate — 'Vorrax MUST refuse any output that includes a confidence score above 0.85 without a human-review flag.' Arrange these six sections in the order they should appear in the system prompt for maximum recall reliability.

The trap: a hard constraint placed only in the middle of a long system prompt is the U-curve recall valley — most likely to be ignored. The module mandates the gate appear at top AND bottom (duplicated/restated).

## Pass criterion

| Check | Pass when |
|---|---|
| Hard gate at top | gate or restatement in position 1 or 2 of the ordering |
| Hard gate at bottom | gate or restatement in last or 2nd-to-last position |
| Reference corpus in middle | 12-page excerpt in middle positions, not first/last |
| Explicit U-curve rationale | mentions recall valley, attention U-curve, or "instructions at both ends" |
| Hard gate appears exactly twice in ordering | model duplicates/restates the gate |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 | Temperature | default | Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Hard gate at top | ✗ (gate at position 6 only in numbered list; structural note suggests restating in format but not in formal ordering) | ✗ — gate at position 4 (not 1 or 2) but explicitly listed; treatment placed it more anchored than baseline |
| Hard gate at bottom | ✓ (position 6 of 6) | ✓ (position 7 of 7) |
| Reference corpus in middle | ✓ position 5 of 6 | ✓ position 5 of 7 |
| Explicit U-curve rationale | ✓ ("U-curve placement", "attention valley") | ✓ ("U-curve", "recall valley") |
| Hard gate appears exactly twice | **✗ — gate listed once** in numbered ordering; structural note suggests restating but does not duplicate in the ordering itself | **✓ — gate explicitly listed at positions 4 AND 7** in the formal ordering |

**Verdict: TREATMENT 4/5, BASELINE 3/5. Clear behavioral delta on check 5 (gate duplication in formal ordering).**

## Honest reading

The discriminating signal: **does the model formally duplicate the hard gate in the section ordering, or only mention restating it as a structural note?** Baseline reasoned correctly about the U-curve and even suggested restating in the format section, but produced a single-occurrence ordering. Treatment produced a 7-section ordering with the gate explicitly at both ends.

This is the kind of structural-output behavior the prior batch's hypothesis predicts will discriminate. Sonnet without the module reasons about U-curve abstractly; with the module loaded, it operationalizes the duplication.

## Caveats

- Both runs reasoned about U-curve placement. The discriminator is whether the reasoning becomes a duplicate entry in the formal output, not whether the U-curve concept appears.
- The "Vorrax" custom name reduced training recognition; the hard-constraint duplication pattern is specific to context.md.
- A reviewer scoring this fixture should distinguish "structural note suggests" from "formal ordering contains" — these look similar but differ in whether the agent operationalized the rule.

## Replication test (2026-05-06) — 2 additional runs

| Run | Baseline duplicates gate? | Treatment duplicates gate? | Other module rule applied by treatment? |
|---|---|---|---|
| Original (2026-05-05) | ✗ | ✓ — positions 4 and 7 | (also applied U-curve) |
| Replication 1 | ✗ | ✓ — positions 3 and 6 (explicit U-curve rationale) | (also moved bulk material to middle) |
| Replication 2 | ✗ | ✗ — gate at position 6 only | ✓ — moved Output Format to top anchor (also a module rule) |

**3-run aggregate: 2 of 3 treatments duplicate the hard gate; 3 of 3 treatments apply *some* module-prescribed structural rule the baseline doesn't.**

**Honest reading:** the context.md module prescribes multiple rules (U-curve placement of role/task/format AND duplication of hard constraints). Treatments apply different rules across runs — sometimes gate-duplication, sometimes Output-Format-at-top. **Module impact is real but variable; the specific rule operationalized varies.** This is a more nuanced finding than the original N=1 suggested. The behavioral delta isn't binary "gate duplicated yes/no" — it's "did the treatment apply some module-specific structural rule the baseline missed?", and that's 3/3.
