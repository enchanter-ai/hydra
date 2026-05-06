---
name: reach-awareness
description: >
  Post-filters vuln-detector findings by call-graph reachability from an
  entrypoint, so operators triage exploitable vulns first and dead-code or
  vendored-library hits last. Use when the developer wants to triage a
  vuln-detector audit.jsonl, runs /hydra:reach, asks "which of these
  findings are actually reachable?", or references Snyk/CodeQL/Semgrep
  reachability as a reference baseline. Currently scaffolded; full
  integration is blocked on lich exporting a persisted call-graph artifact
  — in graph-absent mode, every finding is preserved with reachable=null.
  Do not use for raw vuln scanning (see vuln-detector) or for first-pass
  CWE classification (see audit-trail).
model: haiku
allowed-tools:
  - Read
  - Bash
---

# reach-awareness

## Preconditions

- `vuln-detector` has run and produced `state/audit.jsonl` with at least
  one `vuln_detected` event.
- A call-graph artifact at the schema documented in this plugin's `README.md`
  exists (or the operator accepts graph-absent mode, where every finding is
  passed through with `reachable=null`).

## Inputs

| Flag           | Default                                            | Meaning |
|----------------|----------------------------------------------------|---------|
| `--audit`      | `../vuln-detector/state/audit.jsonl`               | Source of `vuln_detected` events |
| `--graph`      | (none)                                             | Path to call-graph JSON; absent = graph-absent mode |
| `--out`        | `state/reach-filtered.jsonl`                       | Output path |

## Steps

1. Read the audit file with `Read`. Confirm at least one row has
   `event == "vuln_detected"`.
2. Check whether `--graph` resolves to an existing file. If not, run in
   graph-absent mode and document the reason in the summary stderr line.
3. Run `python scripts/reach-filter.py` with the resolved flags. Stream
   stdout/stderr; the summary line on stderr is the human-readable verdict.
4. If the operator asks about a specific finding, run
   `python scripts/explain-reach.py --finding-id <id>`.

## Outputs

- `state/reach-filtered.jsonl` — one JSON object per input finding, plus
  `reachable`, `distance_from_entry`, `path`.
- Summary line on stderr in the form:
  `vuln-detector raw=N | reachable=M | filtered_unreachable=N-M`

## Handoff

The filtered output is what an operator hands to triage. The raw
`vuln-detector` `audit.jsonl` remains the source of truth — this plugin is
advisory.

## Failure modes

- **F02** — claiming a finding is unreachable without a real graph. Counter:
  in graph-absent mode, `reachable` MUST be `null`, never `false`.
- **F08** — using `grep`/`find` to walk the audit file. Counter: stdlib
  `json` per line; the file is JSONL by contract.
- **F14** — call-graph schema drift between lich and this plugin. Counter:
  validate the graph against the README schema before BFS; on mismatch,
  abort with a non-zero exit and a diagnostic on stderr.
