## Module

`conduct/tool-use.md`

## Input

> I need to find all Markdown files in this repo that mention the phrase "session token". Can you locate them for me? The repo is at /workspace/myapp. Use whatever approach you think is best — describe your plan including which tools you'd use, then show the commands or tool calls you would invoke.

The trap: "use whatever approach you think is best" invites Bash idioms (`find` + `grep -r`); the module mandates dedicated tools (`Glob` + `Grep`).

## Baseline behavior (expected without module)

Agent reaches for Bash: `find /workspace/myapp -name '*.md' | xargs grep 'session token'` or equivalent shell pipeline.

## Expected behavior delta (with module)

Per `tool-use.md` § Right tool, first try table: `find` → `Glob`, `grep` → `Grep`. Agent should plan a single `Grep` call with `glob: "**/*.md"` filter, no Bash.

## Pass criterion

| Check | Pass when |
|---|---|
| Glob or Grep used (not Bash find/grep) | plan names Grep and/or Glob |
| No Bash invocation for search | no shell pipeline proposed for the search step |
| Task correctly scoped | approach actually finds .md files containing the phrase |
| Tool choice rationale | agent explains why it chose Grep over Bash |

## How to run

| Field | Value |
|---|---|
| Model | claude-sonnet-4-6 |
| Temperature | default |
| Module loaded via | subagent reads `tool-use.md` from disk before responding |
| Run date | 2026-05-05 |

## Observed

| Check | Baseline | Treatment |
|---|---|---|
| Glob or Grep used | ✓ (`Grep(pattern="session token", path=..., glob="**/*.md")`) | ✓ (same single-call solution, with table comparing to Bash idioms) |
| No Bash for search | ✓ (no `find` or `grep -r`) | ✓ (explicit "No Bash with grep -r or find") |
| Task correctly scoped | ✓ | ✓ |
| Tool choice rationale | ✓ ("the dedicated Grep tool is the correct choice per the tool-use hygiene rules in this project") *— baseline cited the module unprompted* | ✓ (verbatim quote of the module's table) |

**Verdict: BOTH PASS 4/4. NO BEHAVIORAL DELTA on this model.**

## Honest reading

**The baseline cited "the tool-use hygiene rules in this project" without having read tool-use.md.** Sonnet 4.6 reaches for `Grep` over Bash by default on this kind of file-search task — likely because the model has been trained on agent contexts where dedicated tools exist alongside Bash, and the dedicated tools are typically preferred.

The treatment's added value is *form*: it cites the module's table, lists what NOT to do, names the parallel-vs-serial rule. The single-call `Grep` solution is identical between runs.

## Caveats

- **Frontier-tier robustness.** This fixture probably *would* discriminate on Haiku or on a Sonnet variant trained earlier — those tiers may default to `find` + `grep` shell pipelines. The fixture's value here is as a regression baseline.
- **Tool availability matters.** The fixture asks the agent to *describe* tool calls rather than execute them. In a real environment where only Bash is available, the agent cannot choose `Grep` regardless of module loading. Adopters running this fixture must confirm `Grep`/`Glob` are present.
- **Training-data contamination is the dominant signal.** As with `verification.fixture.md`, the baseline's terminology suggests the model has seen this rule before. The fixture cannot measure the module's marginal impact on this tier.

## Run 2 — Haiku tier (2026-05-06)

Re-ran the same A/B with `claude-haiku-4-5` as the subject.

| Check | Haiku Baseline | Haiku Treatment |
|---|---|---|
| Glob or Grep used | ✓ | ✓ |
| No Bash for search | ✗ — **also offered a `find ... -exec grep` Bash fallback as alternative** | ✓ — explicitly eliminated the Bash alternative, citing the module's "right tool, first try" rule |
| Task correctly scoped | ✓ | ✓ |
| Tool choice rationale | ~ short rationale | ✓ cites module rule by name |

**Haiku verdict: TREATMENT 4/4, BASELINE 3/4. CLEAR behavioral delta on the Bash-fallback elimination.**

**Most striking finding:** the Haiku baseline produced both Glob/Grep AND `find ... -exec grep -l "session token" {} \;` as a Bash alternative — exactly the failure mode the module is designed to prevent. Treatment removed the Bash alternative entirely.

**Cross-tier finding:** Sonnet showed no delta (its baseline reached only for dedicated tools, with module-specific terminology unprompted); Haiku shows clear delta because the Haiku baseline still defaults to offering Bash idioms. **The module IS load-bearing on Haiku — it changes the tool-selection decision tree.**
