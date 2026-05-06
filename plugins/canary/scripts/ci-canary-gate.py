#!/usr/bin/env python3
"""
ci-canary-gate: CI gate that promotes the canary plugin from advisory-only
runtime hook to a CI-blocking detection check on prompt-injection fixtures.

Closes ecosystem-audit finding F-004 (advisory -> CI-blocked detection of
indirect prompt-injection canary leakage).

Contract:
  - Loads every fixture under plugins/canary/fixtures/injection/*.json.
  - For each fixture, seeds a *temporary* active-canaries.json with the
    fixture's canary_token, builds a synthetic PostToolUse hook payload
    from fixture.input + fixture.output, and pipes it into
    scripts/canary-scan.py.
  - Asserts the scanner emits a `HIT: canary <TOKEN>` advisory on stderr
    AND appends a finding to a *temporary* hits.ndjson.
  - Restores the original state files (or removes them if they did not
    exist) before exit.
  - Exits 0 only if every fixture detected the canary leak. Any miss ->
    non-zero exit, which fails the GitHub Actions check.

Runtime hook semantics are unchanged: posttooluse-scan.sh still exits 0
unconditionally (advisory-only per shared/foundations/conduct/hooks.md). This gate
only verifies that the *detection* surface fires correctly against the
fixture set.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
FIXTURE_DIR = PLUGIN_ROOT / "fixtures" / "injection"
SCAN_SCRIPT = PLUGIN_ROOT / "scripts" / "canary-scan.py"
STATE_DIR = PLUGIN_ROOT / "state"
ACTIVE_FILE = STATE_DIR / "active-canaries.json"
HITS_FILE = STATE_DIR / "hits.ndjson"
DEFAULT_BASELINE = PLUGIN_ROOT / "baseline-2026-05-06.json"


def _load_fixtures() -> list[dict]:
    if not FIXTURE_DIR.is_dir():
        sys.stderr.write(f"FAIL: fixture directory missing: {FIXTURE_DIR}\n")
        sys.exit(2)
    fixtures: list[dict] = []
    for path in sorted(FIXTURE_DIR.glob("*.json")):
        try:
            with path.open("r", encoding="utf-8") as f:
                fx = json.load(f)
        except Exception as e:
            sys.stderr.write(f"FAIL: cannot parse fixture {path.name}: {e}\n")
            sys.exit(2)
        fx["__path"] = str(path)
        fixtures.append(fx)
    return fixtures


def _seed_active(token: str) -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "sessions": {
            "ci-fixture": {
                "token": token,
                "created_ts": 0,
            }
        }
    }
    ACTIVE_FILE.write_text(json.dumps(payload), encoding="utf-8")


def _build_hook_payload(fx: dict) -> str:
    return json.dumps(
        {
            "tool_name": "WebFetch",
            "tool_input": fx.get("input", "") or "",
            "tool_response": fx.get("output", "") or "",
            "session_id": "ci-fixture",
        },
        ensure_ascii=False,
    )


def _run_scan(payload: str) -> tuple[int, str]:
    result = subprocess.run(
        [sys.executable, str(SCAN_SCRIPT)],
        input=payload,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    return result.returncode, result.stderr or ""


def _hits_contains(token: str) -> bool:
    if not HITS_FILE.exists():
        return False
    try:
        with HITS_FILE.open("r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                if rec.get("token") == token:
                    return True
    except Exception:
        return False
    return False


def _restore(snapshot: dict) -> None:
    for path, original in snapshot.items():
        p = Path(path)
        if original is None:
            if p.exists():
                try:
                    p.unlink()
                except Exception:
                    pass
        else:
            try:
                p.write_bytes(original)
            except Exception:
                pass


def _snapshot() -> dict:
    snap: dict = {}
    for p in (ACTIVE_FILE, HITS_FILE):
        snap[str(p)] = p.read_bytes() if p.exists() else None
    return snap


def _load_baseline(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write(f"WARN: cannot parse baseline {path}: {e}\n")
        return None


def _compare_baseline(baseline: dict, fixtures_total: int, detected: int) -> tuple[bool, str]:
    """Return (regression, message). Regression = current rate dropped >= threshold."""
    base_rate = float(baseline.get("detection_rate", 0.0))
    threshold = float(baseline.get("regression_threshold_drop", 0.05))
    cur_rate = detected / fixtures_total if fixtures_total else 0.0
    drop = base_rate - cur_rate
    if drop >= threshold:
        return True, (
            f"REGRESSION: detection_rate dropped {drop:.3f} "
            f"(baseline={base_rate:.3f} current={cur_rate:.3f} "
            f"threshold={threshold:.3f})"
        )
    return False, (
        f"baseline OK: detection_rate {cur_rate:.3f} vs baseline {base_rate:.3f} "
        f"(drop {drop:+.3f}, threshold {threshold:.3f})"
    )


def main() -> int:
    parser = argparse.ArgumentParser(prog="ci-canary-gate")
    parser.add_argument(
        "--baseline",
        nargs="?",
        const=str(DEFAULT_BASELINE),
        default=None,
        help=(
            "Compare detection rate to a recorded baseline JSON; fail if the "
            "current rate drops by >= regression_threshold_drop. Pass the flag "
            "alone to use the default baseline at "
            f"{DEFAULT_BASELINE.name}."
        ),
    )
    args = parser.parse_args()
    baseline = _load_baseline(Path(args.baseline)) if args.baseline else None
    if args.baseline and baseline is None:
        sys.stderr.write(f"FAIL: --baseline given but file unreadable: {args.baseline}\n")
        return 2

    if not SCAN_SCRIPT.exists():
        sys.stderr.write(f"FAIL: scanner missing: {SCAN_SCRIPT}\n")
        return 2

    fixtures = _load_fixtures()
    if len(fixtures) < 10:
        sys.stderr.write(
            f"FAIL: expected >= 10 fixtures, found {len(fixtures)}\n"
        )
        return 2

    snap = _snapshot()
    # Use a fresh hits file per gate run for clean accounting.
    if HITS_FILE.exists():
        HITS_FILE.unlink()

    failures: list[str] = []
    passes: list[str] = []

    try:
        for fx in fixtures:
            fid = fx.get("id") or Path(fx["__path"]).stem
            token = fx.get("canary_token", "")
            if not token:
                failures.append(f"{fid}: missing canary_token")
                continue
            _seed_active(token)
            # Reset hits.ndjson per fixture for isolated detection check.
            if HITS_FILE.exists():
                HITS_FILE.unlink()
            payload = _build_hook_payload(fx)
            rc, stderr = _run_scan(payload)
            if rc != 0:
                failures.append(
                    f"{fid}: scanner exited rc={rc} (advisory contract violated)"
                )
                continue
            stderr_hit = ("HIT:" in stderr) and (token in stderr)
            ndjson_hit = _hits_contains(token)
            if not (stderr_hit and ndjson_hit):
                failures.append(
                    f"{fid}: leak NOT detected (stderr_hit={stderr_hit} "
                    f"ndjson_hit={ndjson_hit}) token={token}"
                )
                continue
            passes.append(fid)
    finally:
        _restore(snap)

    sys.stdout.write("=== canary CI gate ===\n")
    sys.stdout.write(f"fixtures: {len(fixtures)}\n")
    sys.stdout.write(f"passed:   {len(passes)}\n")
    sys.stdout.write(f"failed:   {len(failures)}\n")
    for fid in passes:
        sys.stdout.write(f"  PASS {fid}\n")
    for msg in failures:
        sys.stdout.write(f"  FAIL {msg}\n")

    if baseline is not None:
        regressed, msg = _compare_baseline(baseline, len(fixtures), len(passes))
        sys.stdout.write(f"\n{msg}\n")
        if regressed:
            sys.stdout.write(
                "F-004 CI gate FAILED: detection-rate regression vs baseline.\n"
            )
            return 1

    if failures:
        sys.stdout.write(
            "\nF-004 CI gate FAILED: one or more injection fixtures did "
            "not produce a canary leak detection.\n"
        )
        return 1

    sys.stdout.write(
        "\nF-004 CI gate PASSED: all injection fixtures produced a "
        "canary leak detection (advisory -> CI-blocked).\n"
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
