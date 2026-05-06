#!/usr/bin/env python3
"""explain-reach — operator-runnable explainer for a single reach verdict.

Takes a finding ID (as emitted by reach-filter.py) and prints the reach
analysis verdict plus the call path entry -> vulnerable function. Used by
the operator during triage to understand *why* a particular finding was
classified reachable / unreachable / null.

Stdlib only. Reads from reach-filtered.jsonl.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Optional


def _find_row(out_path: Path, finding_id: str) -> Optional[dict[str, Any]]:
    """Linear scan of reach-filtered.jsonl for the matching finding ID."""
    if not out_path.exists():
        print(
            f"explain-reach: {out_path} does not exist — run reach-filter.py "
            f"first",
            file=sys.stderr,
        )
        return None
    with out_path.open("r", encoding="utf-8") as fh:
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
            if row.get("finding_id") == finding_id:
                return row
    return None


def _format_verdict(row: dict[str, Any]) -> str:
    reach = row.get("reachable")
    if reach is None:
        return "UNKNOWN (graph absent or function node not resolvable)"
    return "REACHABLE" if reach else "UNREACHABLE"


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Explain the reach verdict for a single finding."
    )
    parser.add_argument(
        "--finding-id",
        required=True,
        help='Finding ID as emitted by reach-filter (form "<file>:<line>:<vuln_id>")',
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "state" / "reach-filtered.jsonl",
        help="Path to reach-filtered.jsonl",
    )
    args = parser.parse_args(argv)

    row = _find_row(args.out, args.finding_id)
    if row is None:
        print(
            f"explain-reach: no finding with id {args.finding_id!r} in "
            f"{args.out}",
            file=sys.stderr,
        )
        return 1

    print(f"finding_id  : {row.get('finding_id')}")
    print(f"file:line   : {row.get('file', '?')}:{row.get('line', '?')}")
    print(f"vuln_id     : {row.get('vuln_id', '?')}")
    print(f"cwe         : {row.get('cwe', '?')}")
    print(f"severity    : {row.get('severity', '?')}")
    print(f"verdict     : {_format_verdict(row)}")
    dist = row.get("distance_from_entry")
    print(f"distance    : {dist if dist is not None else '-'}")
    path = row.get("path")
    if path:
        print("call path   :")
        for i, fn in enumerate(path):
            print(f"  [{i}] {fn}")
    else:
        print("call path   : -")
    return 0


if __name__ == "__main__":
    sys.exit(main())
