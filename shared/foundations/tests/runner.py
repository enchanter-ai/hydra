"""
Reference implementation — stupid-agent fixture runner for agent-foundations conduct modules.

Reference implementation. Production adopters should swap for Promptfoo / Inspect-AI / their stack.
This file is one possible runner; the framework is dependency-free Markdown + the shell installer.
Promptfoo and Inspect-AI are valid alternatives. Pick the one that fits your stack.

Usage:
    python runner.py tests/<module>.fixture.md
    python runner.py tests/<module>.fixture.md --apply
    python runner.py tests/<module>.fixture.md --verifier-only
"""

import anthropic
import argparse
import json
import pathlib
import re
import sys

# ---------------------------------------------------------------------------
# Cost cap — refuse to run any fixture that would exceed this token budget.
# Counts input + output tokens across all three calls (baseline, treatment, verifier).
MAX_TOKENS_PER_FIXTURE = 20_000

# Model assignments per the three-tier architecture in recipes/stupid-agent-review.md
SUBJECT_MODEL  = "claude-sonnet-4-6"   # mid-tier: performs the task
VERIFIER_MODEL = "claude-haiku-4-5"    # low-tier: structural boolean checks

# Per-call output cap — keeps single calls from eating the whole budget
MAX_OUTPUT_TOKENS = 2_048

# Rough cost per million tokens (input / output) for budget logging, USD
COST_PER_M = {
    "claude-sonnet-4-6": (3.00, 15.00),
    "claude-haiku-4-5":  (0.80,  4.00),
}
# ---------------------------------------------------------------------------


def _cost_usd(model: str, in_tok: int, out_tok: int) -> float:
    c_in, c_out = COST_PER_M.get(model, (5.00, 25.00))
    return (in_tok * c_in + out_tok * c_out) / 1_000_000


def _log(role: str, model: str, in_tok: int, out_tok: int) -> None:
    cost = _cost_usd(model, in_tok, out_tok)
    print(
        f"[obs] model={model} role={role} "
        f"in={in_tok} out={out_tok} cost_usd={cost:.5f}",
        file=sys.stderr,
    )


def _call(client: anthropic.Anthropic, role: str, model: str,
          system: str, user: str):
    """Single blocking API call. Exits non-zero on any error — no silent retry."""
    try:
        resp = client.messages.create(
            model=model,
            max_tokens=MAX_OUTPUT_TOKENS,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
    except anthropic.APIError as exc:
        print(f"[error] API call failed (role={role}): {exc}", file=sys.stderr)
        sys.exit(1)

    in_tok  = resp.usage.input_tokens
    out_tok = resp.usage.output_tokens
    _log(role, model, in_tok, out_tok)
    return resp.content[0].text, in_tok, out_tok


# ---------------------------------------------------------------------------
# Fixture parsing — regex only, no markdown library
# ---------------------------------------------------------------------------

def _section(text: str, heading: str) -> str:
    """Return the text between ## heading and the next ## heading (stripped)."""
    pat = rf"^##\s+{re.escape(heading)}\s*\n(.*?)(?=^##\s|\Z)"
    m = re.search(pat, text, re.MULTILINE | re.DOTALL)
    if not m:
        return ""
    return m.group(1).strip()


def _parse_criterion_table(section_text: str):
    """Extract rows from a markdown table as list of {check, pass_when} dicts."""
    rows = []
    for line in section_text.splitlines():
        line = line.strip()
        if not line.startswith("|") or line.startswith("| Check") or set(line) <= set("|-: "):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) >= 2:
            rows.append({"check": cells[0], "pass_when": cells[1]})
    return rows


def _parse_fixture(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    module_raw = _section(text, "Module")
    m = re.search(r"`?(?:conduct/)?(\S+\.md)`?", module_raw)
    module_file = m.group(1) if m else module_raw.strip()

    return {
        "raw":        text,
        "module":     module_file,
        "input":      _section(text, "Input"),
        "criterion":  _parse_criterion_table(_section(text, "Pass criterion")),
    }


def _find_module(fixture_path: pathlib.Path, module_file: str) -> pathlib.Path:
    """Resolve the conduct module relative to the fixture file's repo root."""
    candidate = fixture_path.parent
    for _ in range(6):
        conduct_dir = candidate / "conduct"
        if conduct_dir.is_dir():
            mod = conduct_dir / module_file
            if mod.exists():
                return mod
        candidate = candidate.parent
    raise FileNotFoundError(
        f"Could not locate conduct/{module_file} near {fixture_path}"
    )


# ---------------------------------------------------------------------------
# Verifier prompt builder
# ---------------------------------------------------------------------------

VERIFIER_SYSTEM = """\
You are a structural verifier. You apply boolean pass/fail checks to two text outputs.
Return ONLY valid JSON — no prose, no markdown fences, no explanation outside the JSON.
Schema: {"baseline": [{"check": "...", "pass": true|false}], \
"treatment": [{"check": "...", "pass": true|false}]}
Each check appears exactly once in each list, in the order given.
Apply each criterion literally and structurally. Do NOT assess quality or style.\
"""


def _verifier_prompt(baseline_out: str, treatment_out: str, criterion):
    checks_text = "\n".join(
        f"  {i+1}. check: {r['check']} | pass when: {r['pass_when']}"
        for i, r in enumerate(criterion)
    )
    return (
        f"Checks to apply:\n{checks_text}\n\n"
        f"--- BASELINE OUTPUT ---\n{baseline_out}\n\n"
        f"--- TREATMENT OUTPUT ---\n{treatment_out}"
    )


# ---------------------------------------------------------------------------
# Result formatting
# ---------------------------------------------------------------------------

def _format_observed(criterion, baseline_results, treatment_results, module: str) -> str:
    """Produce the markdown Observed table."""
    header  = "| Check | Baseline | Treatment |\n|---|---|---|\n"
    rows = []
    b_pass = sum(1 for r in baseline_results  if r.get("pass"))
    t_pass = sum(1 for r in treatment_results if r.get("pass"))
    n = len(criterion)
    for b, t in zip(baseline_results, treatment_results):
        b_sym = "PASS" if b.get("pass") else "FAIL"
        t_sym = "PASS" if t.get("pass") else "FAIL"
        rows.append(f"| {b['check']} | {b_sym} | {t_sym} |")
    rows_text = "\n".join(rows)

    if (t_pass - b_pass) >= 2:
        delta = "clear delta"
    elif t_pass == b_pass:
        delta = "no delta"
    else:
        delta = "borderline delta"
    verdict = (f"**Verdict: TREATMENT {t_pass}/{n}, BASELINE {b_pass}/{n}. "
               f"{delta.upper()} on {module}.**")

    return f"## Observed\n\n{header}{rows_text}\n\n{verdict}\n"


def _apply_observed(fixture_path: pathlib.Path, observed_md: str) -> None:
    """Replace (or append) the Observed section in the fixture file."""
    text = fixture_path.read_text(encoding="utf-8")
    pat = r"^##\s+Observed\s*\n.*"
    if re.search(pat, text, re.MULTILINE | re.DOTALL):
        updated = re.sub(pat, observed_md.rstrip(), text, flags=re.MULTILINE | re.DOTALL)
    else:
        updated = text.rstrip() + "\n\n" + observed_md
    fixture_path.write_text(updated, encoding="utf-8")


# ---------------------------------------------------------------------------
# Existing output extraction (--verifier-only)
# ---------------------------------------------------------------------------

def _extract_existing_outputs(fixture):
    """Pull verbatim output blocks from an already-populated Observed section."""
    raw = fixture["raw"]
    obs = _section(raw, "Observed")

    def _between(label: str) -> str:
        m = re.search(
            rf"---\s*{re.escape(label)}\s*---\s*\n(.*?)(?=---|$)",
            obs, re.DOTALL | re.IGNORECASE
        )
        return m.group(1).strip() if m else ""

    baseline  = _between("BASELINE OUTPUT")
    treatment = _between("TREATMENT OUTPUT")

    if not baseline or not treatment:
        blocks = re.findall(r"```.*?\n(.*?)```", obs, re.DOTALL)
        baseline  = blocks[0].strip() if len(blocks) > 0 else ""
        treatment = blocks[1].strip() if len(blocks) > 1 else ""

    if not baseline or not treatment:
        print("[error] --verifier-only: could not extract baseline and treatment "
              "outputs from Observed section.", file=sys.stderr)
        sys.exit(1)
    return baseline, treatment


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Stupid-agent fixture runner — reference implementation."
    )
    parser.add_argument("fixture", type=pathlib.Path,
                        help="Path to <module>.fixture.md")
    parser.add_argument("--apply", action="store_true",
                        help="Rewrite the fixture file's Observed section in-place.")
    parser.add_argument("--verifier-only", action="store_true",
                        help="Skip subject calls; use existing outputs in Observed section.")
    args = parser.parse_args()

    if not args.fixture.exists():
        print(f"[error] Fixture not found: {args.fixture}", file=sys.stderr)
        sys.exit(1)

    fixture = _parse_fixture(args.fixture)

    if not fixture["criterion"]:
        print("[error] No pass-criterion table found in fixture.", file=sys.stderr)
        sys.exit(1)

    try:
        module_path = _find_module(args.fixture, fixture["module"])
    except FileNotFoundError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        sys.exit(1)

    module_text = module_path.read_text(encoding="utf-8")
    task_input  = fixture["input"]

    client = anthropic.Anthropic()

    total_tokens = 0

    if args.verifier_only:
        print("[info] --verifier-only: skipping subject calls.", file=sys.stderr)
        baseline_out, treatment_out = _extract_existing_outputs(fixture)
        total_tokens = len(baseline_out.split()) * 2 + len(treatment_out.split()) * 2
    else:
        est_subject_in  = (len(task_input) // 4) * 2
        est_module_in   = len(module_text) // 4
        est_verifier_in = (len(task_input) // 4) + MAX_OUTPUT_TOKENS * 2
        est_total       = est_subject_in + est_module_in + est_verifier_in + MAX_OUTPUT_TOKENS * 3
        if est_total > MAX_TOKENS_PER_FIXTURE:
            print(
                f"[error] Estimated token usage ({est_total:,}) exceeds "
                f"MAX_TOKENS_PER_FIXTURE ({MAX_TOKENS_PER_FIXTURE:,}). "
                "Refusing to run. Shorten the fixture input or the module.",
                file=sys.stderr,
            )
            sys.exit(1)

        print("[info] Dispatching baseline subject (no module)...", file=sys.stderr)
        baseline_out, b_in, b_out = _call(
            client, "subject_baseline", SUBJECT_MODEL,
            system="You are a helpful assistant.",
            user=task_input,
        )
        total_tokens += b_in + b_out

        print("[info] Dispatching treatment subject (module loaded)...", file=sys.stderr)
        treatment_out, t_in, t_out = _call(
            client, "subject_treatment", SUBJECT_MODEL,
            system=module_text,
            user=task_input,
        )
        total_tokens += t_in + t_out

    if total_tokens > MAX_TOKENS_PER_FIXTURE:
        print(
            f"[error] Token usage so far ({total_tokens:,}) already exceeds cap "
            f"({MAX_TOKENS_PER_FIXTURE:,}). Aborting before verifier call.",
            file=sys.stderr,
        )
        sys.exit(1)

    print("[info] Dispatching verifier...", file=sys.stderr)
    verifier_prompt = _verifier_prompt(baseline_out, treatment_out, fixture["criterion"])
    verifier_raw, v_in, v_out = _call(
        client, "verifier", VERIFIER_MODEL,
        system=VERIFIER_SYSTEM,
        user=verifier_prompt,
    )
    total_tokens += v_in + v_out

    try:
        clean = re.sub(r"```(?:json)?\s*|\s*```", "", verifier_raw).strip()
        verdict = json.loads(clean)
        baseline_results  = verdict["baseline"]
        treatment_results = verdict["treatment"]
    except (json.JSONDecodeError, KeyError) as exc:
        print(f"[error] Verifier returned invalid JSON: {exc}\nRaw:\n{verifier_raw}",
              file=sys.stderr)
        sys.exit(1)

    observed_md = _format_observed(
        fixture["criterion"], baseline_results, treatment_results, fixture["module"]
    )
    print(observed_md)

    if args.apply:
        _apply_observed(args.fixture, observed_md)
        print(f"[info] Fixture updated in-place: {args.fixture}", file=sys.stderr)

    print(f"[obs] total_tokens_used={total_tokens:,} cap={MAX_TOKENS_PER_FIXTURE:,}",
          file=sys.stderr)


if __name__ == "__main__":
    main()
