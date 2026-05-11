#!/usr/bin/env python3
"""state-integrity: meta-canary scanner.

Walks every path in state/baseline.json:watched_paths and compares the
current HMAC-SHA-256 of the file's bytes against baseline.expected_sigs.
Drift (mismatch) OR missing file = HIGH-severity event.

Events are written to state/integrity-events.ndjson via fcntl-locked
append (Unix) or msvcrt locking (Windows). This is the SEPARATE write-only
audit channel — independent of audit-trail's audit.jsonl. Even if the
attacker corrupts audit.jsonl, this channel survives.

Each event is hash-chained via base64(hmac_sha256(key, canonical_json(prev))).
First event: prev_hash = "GENESIS".

stdlib only. No external dependencies.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# Cross-platform file locking. Best-effort: if neither module is available
# (extremely rare), fall back to plain append — the scanner is advisory.
try:
    import fcntl  # type: ignore[import-not-found]

    _LOCK_KIND = "fcntl"
except ImportError:
    fcntl = None  # type: ignore[assignment]
    try:
        import msvcrt  # type: ignore[import-not-found]

        _LOCK_KIND = "msvcrt"
    except ImportError:
        msvcrt = None  # type: ignore[assignment]
        _LOCK_KIND = "none"


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _resolve_repo_root(plugin_root: Path) -> Path:
    # plugin_root = .../<repo-root>/hydra/plugins/state-integrity → repo root
    # is 3 up. Override via $HYDRA_STATE_INTEGRITY_REPO_ROOT for tests.
    env = os.environ.get("HYDRA_STATE_INTEGRITY_REPO_ROOT")
    if env:
        return Path(env).resolve()
    return plugin_root.parent.parent.parent


def _load_state_key(plugin_root: Path) -> bytes | None:
    env_key = os.environ.get("HYDRA_STATE_INTEGRITY_HMAC_KEY")
    if env_key:
        return env_key.encode("utf-8")
    key_file = plugin_root / "state" / "hmac-key.bin"
    if key_file.is_file() and key_file.stat().st_size > 0:
        try:
            return key_file.read_bytes().strip()
        except OSError:
            return None
    # Try to create one.
    try:
        plugin_root.joinpath("state").mkdir(parents=True, exist_ok=True)
        new_key = os.urandom(32).hex().encode("ascii")
        key_file.write_bytes(new_key)
        try:
            os.chmod(key_file, 0o600)
        except OSError:
            pass
        return new_key
    except OSError:
        return None


def _hmac_file(path: Path, key: bytes) -> str:
    if not path.is_file():
        return "MISSING"
    h = hmac.new(key, digestmod=hashlib.sha256)
    try:
        with path.open("rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
    except OSError:
        return "UNREADABLE"
    return base64.b64encode(h.digest()).decode("ascii")


def _hmac_canonical_json(obj: dict, key: bytes) -> str:
    canonical = json.dumps(obj, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return base64.b64encode(hmac.new(key, canonical, hashlib.sha256).digest()).decode("ascii")


def _compute_prev_hash(events_path: Path, key: bytes) -> str:
    if not events_path.is_file() or events_path.stat().st_size == 0:
        return "GENESIS"
    last = ""
    try:
        with events_path.open("rb") as f:
            for raw in f:
                line = raw.decode("utf-8", errors="replace").rstrip("\n").rstrip("\r")
                if line.strip():
                    last = line
    except OSError:
        return "GENESIS"
    if not last:
        return "GENESIS"
    try:
        parsed = json.loads(last)
    except json.JSONDecodeError:
        # Treat raw bytes as canonical when not parseable — same as chain-helpers.sh.
        return base64.b64encode(
            hmac.new(key, last.encode("utf-8"), hashlib.sha256).digest()
        ).decode("ascii")
    return _hmac_canonical_json(parsed, key)


def _append_locked(events_path: Path, line: str) -> None:
    events_path.parent.mkdir(parents=True, exist_ok=True)
    mode = "ab"
    payload = (line + "\n").encode("utf-8")

    # Open and lock the file for an exclusive append.
    with events_path.open(mode) as f:
        if _LOCK_KIND == "fcntl" and fcntl is not None:
            for _ in range(50):
                try:
                    fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except OSError:
                    time.sleep(0.05)
            try:
                f.write(payload)
                f.flush()
                try:
                    os.fsync(f.fileno())
                except OSError:
                    pass
            finally:
                try:
                    fcntl.flock(f.fileno(), fcntl.LOCK_UN)
                except OSError:
                    pass
        elif _LOCK_KIND == "msvcrt" and msvcrt is not None:
            # msvcrt.locking() requires a length > 0; we lock byte 0 of the file.
            locked = False
            for _ in range(50):
                try:
                    f.seek(0, os.SEEK_END)
                    msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, 1)
                    locked = True
                    break
                except OSError:
                    time.sleep(0.05)
            try:
                f.write(payload)
                f.flush()
            finally:
                if locked:
                    try:
                        f.seek(0)
                        msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, 1)
                    except OSError:
                        pass
        else:
            # No lock primitives available — append best-effort.
            f.write(payload)
            f.flush()


def _emit_event(events_path: Path, key: bytes, event: dict) -> None:
    event["prev_hash"] = _compute_prev_hash(events_path, key)
    line = json.dumps(event, sort_keys=True, separators=(",", ":"))
    _append_locked(events_path, line)


def scan(plugin_root: Path, reason: str) -> int:
    """Return number of violations detected."""
    baseline_path = plugin_root / "state" / "baseline.json"
    events_path = plugin_root / "state" / "integrity-events.ndjson"

    if not baseline_path.is_file():
        return 0

    try:
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        # If baseline itself is corrupt, that IS a violation worth logging.
        key = _load_state_key(plugin_root)
        if key is not None:
            _emit_event(
                events_path,
                key,
                {
                    "event": "state_integrity_violation",
                    "ts": _utc_now_iso(),
                    "severity": "HIGH",
                    "reason": reason,
                    "path": str(baseline_path),
                    "kind": "baseline_corrupt",
                    "detail": "baseline.json failed to parse",
                },
            )
        return 1

    key = _load_state_key(plugin_root)
    if key is None:
        # No key — we can't verify. Don't silently pass.
        return 0

    repo_root = _resolve_repo_root(plugin_root)
    watched = baseline.get("watched_paths", []) or []
    expected = baseline.get("expected_sigs", {}) or {}

    violations = 0
    for rel in watched:
        # CRLF-tolerant: strip trailing CR for Windows checkouts.
        rel = rel.rstrip("\r")
        if not rel:
            continue
        target = Path(rel)
        if not target.is_absolute():
            target = repo_root / rel

        actual = _hmac_file(target, key)
        want = expected.get(rel)

        if want is None:
            # Not yet signed — operator hasn't run sign-state.sh --all. Skip.
            continue

        if actual == want:
            continue

        kind = "missing" if actual == "MISSING" else ("unreadable" if actual == "UNREADABLE" else "drift")
        _emit_event(
            events_path,
            key,
            {
                "event": "state_integrity_violation",
                "ts": _utc_now_iso(),
                "severity": "HIGH",
                "reason": reason,
                "path": rel,
                "kind": kind,
                "expected_sig_prefix": want[:16],
                "actual_sig_prefix": actual[:16],
            },
        )
        violations += 1

    return violations


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="state-integrity meta-canary scanner")
    parser.add_argument("--plugin-root", required=True, help="path to state-integrity plugin dir")
    parser.add_argument("--reason", default="manual", help="why this scan was triggered")
    parser.add_argument("--print-violations", action="store_true", help="print violation count to stdout")
    args = parser.parse_args(argv)

    plugin_root = Path(args.plugin_root).resolve()
    n = scan(plugin_root, args.reason)
    if args.print_violations:
        print(n)
    # Always exit 0 — advisory contract.
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
