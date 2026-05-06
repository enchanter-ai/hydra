# reach-filter

Reachability-aware post-filter for Hydra's `vuln-detector`. Consumes
`vuln-detector`'s `audit.jsonl` (raw pattern-matched findings) plus a
call-graph artifact and emits a reach-classified subset that distinguishes
**"reachable from an entrypoint"** from **"present-but-unreachable"** vulns.

Closes audit finding **F-039** (reachability-aware SCA, ~25% partial in raw
vuln-detector). Closure is **scaffolded with a lich-integration TODO** — see
[Status](#status) below.

## What

Pattern-matched SCA — like `vuln-detector` — flags every occurrence of a
vulnerable pattern. In real codebases most flagged occurrences are dead code,
test fixtures, vendored examples, or library code never invoked by the
shipping entrypoints. **Snyk Reachability**, **GitHub CodeQL**, and **Semgrep
Pro** all post-filter raw SCA hits with a call-graph reachability check. This
plugin does the same for Hydra.

| Tool                  | Reach mechanism                                   |
|-----------------------|---------------------------------------------------|
| Snyk Reachability     | Java/JS/Python call-graph (proprietary)           |
| GitHub CodeQL         | Code property graph (CPG) data-flow + call-graph  |
| Semgrep Pro           | Inter-procedural taint + call-graph               |
| **Hydra reach-filter**| Operator-run; consumes a call-graph artifact      |

## When

After running `vuln-detector` (which fires on `PostToolUse(Write|Edit)` or
via `/hydra:vulns`), pipe the resulting `audit.jsonl` through `reach-filter`
to suppress findings on functions that no entrypoint can reach.

The filtered output is what an operator hands to triage. The raw
`vuln-detector` output remains the source of truth — reach-filter is
advisory.

## How

```bash
# 1. vuln-detector populates state/audit.jsonl as the developer edits files
# 2. Operator runs the filter (off by default; never auto-fires):
python hydra/plugins/reach-filter/scripts/reach-filter.py \
  --audit  hydra/plugins/vuln-detector/state/audit.jsonl \
  --graph  <path-to-lich-call-graph.json> \
  --out    hydra/plugins/reach-filter/state/reach-filtered.jsonl

# 3. Optionally explain a single finding:
python hydra/plugins/reach-filter/scripts/explain-reach.py \
  --finding-id <id-from-reach-filtered.jsonl> \
  --out hydra/plugins/reach-filter/state/reach-filtered.jsonl
```

`reach-filter.py` walks each finding's `(file, line)` to a function node in
the graph, then BFS-checks reachability from any declared entrypoint
(CLI, hooks, exported APIs). Output rows preserve the input finding plus:

| Field                  | Type            | Meaning                                  |
|------------------------|-----------------|------------------------------------------|
| `reachable`            | `bool \| null`  | `null` if call-graph unavailable         |
| `distance_from_entry`  | `int \| null`   | BFS hop count from nearest entrypoint    |
| `path`                 | `list[str] \| null` | Function-name chain entry → vuln-fn  |

`null` everywhere = "graph absent, defaulting to reachable" so the operator
errs on the side of NOT suppressing findings.

## Call-graph schema

`reach-filter.py` reads JSON with the following minimal shape:

```json
{
  "nodes": {
    "<function_id>": {
      "file": "src/foo.py",
      "name": "foo_handler",
      "line_start": 10,
      "line_end": 42,
      "is_entrypoint": false
    }
  },
  "edges": [
    {"from": "<caller_id>", "to": "<callee_id>"}
  ],
  "entrypoints": ["<function_id>", "..."]
}
```

`function_id` is opaque (`"<file>:<name>:<line_start>"` is a reasonable
default). `entrypoints` is the canonical list; `is_entrypoint` is a
redundant convenience flag. The script tolerates either being authoritative.

## Status

**SCAFFOLDED, lich integration BLOCKED.**

Lich's `m3_property_graph.py` (`lich/plugins/mantis-core/scripts/`) wraps
Joern as a per-file in-memory subprocess and emits `m1_walker.Flag` records
(point findings, not a graph). It does NOT persist a call-graph artifact.
No `state/call-graph.json`, no `cpg.bin`, no exported edge list exists in
any `lich/plugins/*/state/` directory.

To unblock this plugin:

- Lich's mantis-core needs a `--export-graph` mode that walks Joern's CPG
  and dumps the schema above (or any graph format with files + functions
  + edges + entrypoints), persisted to `lich/plugins/mantis-core/state/`
  or a configurable path.
- Alternatively, a stdlib-only call-graph emitter (Python `ast`, JS via
  `tree-sitter`) at the lich layer would give us a ~70% solution without
  the Joern install footprint.

Until then `reach-filter.py` runs in **graph-absent mode**: every finding
is emitted with `reachable=null`, `distance_from_entry=null`, `path=null`.
The summary line on stderr says
`"vuln-detector raw=N | reachable=N | filtered_unreachable=0 (graph absent)"`.

When the lich graph lands, only `_load_graph()` and the entrypoint discovery
step in `reach-filter.py` should need updates — the BFS and emit logic are
graph-format-agnostic.

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root
[CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation,
failure-modes, tool-use, skill-authoring, hooks, precedent.
