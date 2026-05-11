# hydra-state-integrity

**Defense-of-defense layer.** Closes pentest finding **R-020** (covers F-PT-11/12/13/17): defense-state files (`active-canaries.json`, `egress-policy.json`, `capability-policy.json`, `rate-policy.json`, `hooks.json`, etc.) all fail-safe-on-malformed — which **inverts** under adversarial Write. Corrupting the JSON *disables* the defense rather than triggering it.

This plugin adds three independent mechanisms.

## M1 — Signed defense-state files

Each known defense-state path gets a sidecar HMAC-SHA-256 signature via `scripts/sign-state.sh`. `scripts/verify-state.sh` checks any path (or all) against `state/baseline.json:expected_sigs`. Key resolution mirrors `audit-trail/chain-helpers.sh`:

1. `$HYDRA_STATE_INTEGRITY_HMAC_KEY` env var (preferred, operator-rotated)
2. `state/hmac-key.bin` (auto-generated 256-bit, mode 0600)
3. Refuse to sign with a LOUD WARNING (last resort)

## M2 — Meta-canary on state-file integrity

`scripts/scan-defense-state.py` runs on **every** `PostToolUse:Write|Edit|MultiEdit`. It walks every path in `state/baseline.json:watched_paths`, recomputes its HMAC, and compares against `expected_sigs`. Drift OR missing-file produces a HIGH-severity event labeled `state_integrity_violation`.

The meta-canary is **independent of the canary plugin itself**. Even if the attacker disabled the canary plugin by Writing to `active-canaries.json`, state-integrity catches it on the very next tool call.

## M3 — Separate write-only audit channel

Integrity events go to `state/integrity-events.ndjson` — a separate channel from `audit-trail/state/audit.jsonl`. Append-only via `fcntl.flock` (Unix) or `msvcrt.locking` (Windows). Hash-chained the same way as `audit-trail` (base64 HMAC-SHA-256 over canonical JSON; first line = `GENESIS`).

**Even if `audit-trail/state/audit.jsonl` itself is corrupted** (which is one of the watched paths — the defense literally watches the watchers), state-integrity's NDJSON survives. Verify integrity-events.ndjson the same way as audit.jsonl by walking the prev_hash chain.

## Install

```bash
# 1. Generate or set the HMAC key
export HYDRA_STATE_INTEGRITY_HMAC_KEY=$(openssl rand -hex 32)

# 2. Populate the baseline + sidecar .sig files
bash plugins/state-integrity/scripts/sign-state.sh --all

# 3. Verify
bash plugins/state-integrity/scripts/verify-state.sh --all
```

After install, every Write/Edit/MultiEdit tool call triggers a meta-canary scan. Legitimate operator edits to a watched path require re-signing that path before the next scan, or the operator will see a HIGH-severity event.

## Contract

- **Advisory only.** Hook always exits 0. Per `shared/conduct/hooks.md`, the plugin informs; it does not block.
- **stdlib + bash + openssl + jq.** No pip installs.
- **Does not modify other plugins.** It signs and observes their state files; it never edits them.

## Files

| Path | Role |
|------|------|
| `.claude-plugin/plugin.json` | Plugin manifest |
| `hooks/hooks.json` | PostToolUse matcher (Write\|Edit\|MultiEdit) |
| `hooks/posttooluse-write.sh` | Hook entry; runs the scanner |
| `scripts/sign-state.sh` | Sign one file or all watched files; updates baseline |
| `scripts/verify-state.sh` | Verify one file or all watched files |
| `scripts/scan-defense-state.py` | Meta-canary scanner; writes integrity events |
| `skills/state-integrity-awareness/SKILL.md` | Operator-facing skill |
| `state/baseline.json` | Watched paths + expected signatures (committed) |
| `state/hmac-key.bin` | Auto-generated key, mode 0600 (LOCAL ONLY — gitignored) |
| `state/integrity-events.ndjson` | Append-only HIGH-severity event log (LOCAL) |
| `state/integrity-policy.example.json` | Example operator policy |

## Closes

- **R-020** — defense-of-defense for state files.
- **F-PT-11, F-PT-12, F-PT-13, F-PT-17** — adversarial Write to fail-safe-on-malformed state files.
