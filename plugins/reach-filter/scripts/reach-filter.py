#!/usr/bin/env python3
"""reach-filter — reachability-aware post-filter for vuln-detector findings.

Reads vuln-detector's audit.jsonl, optionally loads a call-graph JSON
artifact, and emits a JSONL stream where every input finding is annotated
with reach metadata (`reachable`, `distance_from_entry`, `path`).

Stdlib only. Off by default. Operator-invoked.

STATUS: lich integration is BLOCKED. Lich's m3_property_graph.py wraps Joern
as a per-file in-memory subprocess and emits Flag records — it does NOT
persist a call-graph. No state/call-graph.json exists in any lich plugin's
state/ directory. When `--graph` is absent or unreadable, this script runs
in *graph-absent mode*: every finding is emitted with `reachable=null` so
the operator does not silently suppress real vulns. See README.md "Status".

TODO(lich-graph-integration): when lich ships `--export-graph` (or an
equivalent persisted artifact), only `_load_graph` and entrypoint discovery
should need updates — `_bfs_reach` and emission logic are format-agnostic.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path
from typing import Any, Optional


# -------------------------------------------------------------------------
# Graph loading
# -------------------------------------------------------------------------


def _load_graph(graph_path: Optional[Path]) -> Optional[dict[str, Any]]:
    """Load a call-graph JSON artifact.

    Returns the parsed dict on success, None when the artifact is absent or
    malformed (graph-absent mode kicks in upstream).

    Schema (minimal):
        {
          "nodes": {"<id>": {"file": str, "name": str,
                             "line_start": int, "line_end": int,
                             "is_entrypoint": bool}},
          "edges": [{"from": "<id>", "to": "<id>"}],
          "entrypoints": ["<id>", ...]
        }

    See README.md for the full schema.
    """
    if graph_path is None:
        return None
    if not graph_path.exists() or not graph_path.is_file():
        print(
            f"reach-filter: graph not found at {graph_path}; running in "
            f"graph-absent mode (every finding -> reachable=null)",
            file=sys.stderr,
        )
        return None
    try:
        raw = json.loads(graph_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(
            f"reach-filter: failed to parse graph at {graph_path}: {exc}; "
            f"running in graph-absent mode",
            file=sys.stderr,
        )
        return None
    if not isinstance(raw, dict):
        print(
            f"reach-filter: graph at {graph_path} is not a JSON object; "
            f"running in graph-absent mode",
            file=sys.stderr,
        )
        return None
    nodes = raw.get("nodes")
    edges = raw.get("edges")
    if not isinstance(nodes, dict) or not isinstance(edges, list):
        print(
            "reach-filter: graph missing required nodes/edges; running in "
            "graph-absent mode",
            file=sys.stderr,
        )
        return None
    return raw


def _entrypoints(graph: dict[str, Any]) -> set[str]:
    """Return the set of entrypoint node IDs.

    Honors both an explicit `entrypoints` list and a per-node
    `is_entrypoint` flag. The union is authoritative — either source is
    sufficient to mark a node as an entrypoint.
    """
    declared = graph.get("entrypoints") or []
    flagged = [
        node_id
        for node_id, meta in graph.get("nodes", {}).items()
        if isinstance(meta, dict) and meta.get("is_entrypoint") is True
    ]
    return {*declared, *flagged}


def _adjacency(graph: dict[str, Any]) -> dict[str, list[str]]:
    """Build a forward adjacency list (caller -> callees) for BFS."""
    adj: dict[str, list[str]] = {nid: [] for nid in graph.get("nodes", {})}
    for edge in graph.get("edges", []):
        if not isinstance(edge, dict):
            continue
        src = edge.get("from")
        dst = edge.get("to")
        if not isinstance(src, str) or not isinstance(dst, str):
            continue
        adj.setdefault(src, []).append(dst)
    return adj


# -------------------------------------------------------------------------
# Finding -> graph node resolution
# -------------------------------------------------------------------------


def _resolve_finding_node(
    graph: dict[str, Any],
    finding_file: str,
    finding_line: int,
) -> Optional[str]:
    """Find the function node whose source range contains `finding_line`.

    Match policy: same `file` (suffix match — paths may differ in absolute
    prefix between graph builder and audit producer) and
    `line_start <= finding_line <= line_end`. Picks the smallest containing
    range when multiple match (innermost function wins).
    """
    best: Optional[tuple[str, int]] = None  # (node_id, span_size)
    for node_id, meta in graph.get("nodes", {}).items():
        if not isinstance(meta, dict):
            continue
        n_file = meta.get("file") or ""
        if not isinstance(n_file, str) or not n_file:
            continue
        if not (finding_file.endswith(n_file) or n_file.endswith(finding_file)):
            continue
        try:
            ls = int(meta.get("line_start", 0))
            le = int(meta.get("line_end", 0))
        except (TypeError, ValueError):
            continue
        if ls <= finding_line <= le:
            span = le - ls
            if best is None or span < best[1]:
                best = (node_id, span)
    return best[0] if best is not None else None


# -------------------------------------------------------------------------
# BFS reachability
# -------------------------------------------------------------------------


def _bfs_reach(
    adj: dict[str, list[str]],
    entrypoints: set[str],
    target: str,
) -> tuple[bool, Optional[int], Optional[list[str]]]:
    """BFS forward from each entrypoint until `target` is hit.

    Returns `(reachable, distance, path)`. Distance is the hop count from
    the nearest entrypoint; path is the function-id chain entry -> target
    (inclusive). When unreachable: `(False, None, None)`.
    """
    if target in entrypoints:
        return True, 0, [target]
    parent: dict[str, str] = {}
    visited: set[str] = set(entrypoints)
    queue: deque[tuple[str, int]] = deque((ep, 0) for ep in entrypoints)
    while queue:
        node, dist = queue.popleft()
        for nxt in adj.get(node, []):
            if nxt in visited:
                continue
            visited.add(nxt)
            parent[nxt] = node
            if nxt == target:
                # Reconstruct path target <- ... <- entrypoint
                path_rev = [nxt]
                cur = nxt
                while cur in parent:
                    cur = parent[cur]
                    path_rev.append(cur)
                return True, dist + 1, list(reversed(path_rev))
            queue.append((nxt, dist + 1))
    return False, None, None


# -------------------------------------------------------------------------
# Audit reading
# -------------------------------------------------------------------------


def _iter_findings(audit_path: Path):
    """Yield `vuln_detected` events from the audit JSONL file."""
    if not audit_path.exists():
        return
    with audit_path.open("r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(row, dict):
                continue
            if row.get("event") != "vuln_detected":
                continue
            yield row


def _finding_id(row: dict[str, Any]) -> str:
    """Stable per-finding identifier for cross-referencing in explain-reach."""
    return f"{row.get('file', '')}:{row.get('line', 0)}:{row.get('vuln_id', '')}"


# -------------------------------------------------------------------------
# Main
# -------------------------------------------------------------------------


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Reachability-aware post-filter for vuln-detector findings.",
    )
    parser.add_argument(
        "--audit",
        type=Path,
        default=Path("../vuln-detector/state/audit.jsonl"),
        help="Path to vuln-detector audit.jsonl",
    )
    parser.add_argument(
        "--graph",
        type=Path,
        default=None,
        help="Path to call-graph JSON (lich export). Absent = graph-absent mode.",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "state" / "reach-filtered.jsonl",
        help="Output JSONL path",
    )
    args = parser.parse_args(argv)

    graph = _load_graph(args.graph)
    if graph is not None:
        adj = _adjacency(graph)
        eps = _entrypoints(graph)
    else:
        adj = {}
        eps = set()

    raw = 0
    reachable = 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as out_fh:
        for row in _iter_findings(args.audit):
            raw += 1
            out: dict[str, Any] = dict(row)
            out["finding_id"] = _finding_id(row)

            if graph is None:
                # Graph-absent mode — never claim unreachable without evidence.
                out["reachable"] = None
                out["distance_from_entry"] = None
                out["path"] = None
                reachable += 1  # Treat as reachable for summary stats.
            else:
                file_path = row.get("file", "")
                try:
                    line_no = int(row.get("line", 0))
                except (TypeError, ValueError):
                    line_no = 0
                node_id = _resolve_finding_node(graph, file_path, line_no)
                if node_id is None:
                    # No matching function node — preserve the finding,
                    # mark reachable=null (under-approximation, not false).
                    out["reachable"] = None
                    out["distance_from_entry"] = None
                    out["path"] = None
                    reachable += 1
                else:
                    is_reachable, dist, path = _bfs_reach(adj, eps, node_id)
                    out["reachable"] = bool(is_reachable)
                    out["distance_from_entry"] = dist
                    out["path"] = path
                    if is_reachable:
                        reachable += 1

            out_fh.write(json.dumps(out, separators=(",", ":")) + "\n")

    if graph is None:
        print(
            f"vuln-detector raw={raw} | reachable={reachable} | "
            f"filtered_unreachable=0 (graph absent)",
            file=sys.stderr,
        )
    else:
        print(
            f"vuln-detector raw={raw} | reachable={reachable} | "
            f"filtered_unreachable={raw - reachable}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
