---
name: state-integrity-awareness
description: >
  Use when the developer asks about defense-state integrity, signed state files,
  meta-canary scans, integrity-events.ndjson, HMAC drift, "did anyone tamper
  with my canaries / egress policy / capability policy / audit log", or
  pentest finding R-020 / F-PT-11/12/13/17. Auto-triggers on: "state
  integrity", "signed state", "meta canary", "integrity drift", "verify
  state", "tampered policy", "defense of defense".
allowed-tools:
  - Read
  - Grep
  - Bash
---

<purpose>
Help the developer reason about, verify, and respond to defense-state
file tampering. The state-integrity plugin signs each known defense-state
file (active-canaries.json, egress-policy.json, capability-policy.json,
rate-policy.json, audit.jsonl, .claude/settings.json) with HMAC-SHA-256
and runs a meta-canary on every Write/Edit. Drift or deletion produces a
HIGH-severity event in a SEPARATE write-only audit channel
(state/integrity-events.ndjson) so the record survives even when the
primary audit chain (audit-trail/state/audit.jsonl) is itself the target.
</purpose>

<constraints>
1. NEVER print the contents of state/hmac-key.bin or
   $HYDRA_STATE_INTEGRITY_HMAC_KEY — they are the trust root.
2. NEVER edit state/integrity-events.ndjson by hand — it is append-only
   and hash-chained. Hand edits invalidate the chain.
3. ALWAYS verify with scripts/verify-state.sh, not by eyeballing JSON.
4. ALWAYS treat a HIGH-severity event as adversarial until proven
   otherwise — even a "harmless" reformat of active-canaries.json
   should be investigated, because the whole point of the defense is
   that it cannot tell intent from a byte diff.
</constraints>

<decision_tree>
IF developer asks "is my defense-state intact":
  → Run: bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-state.sh --all
  → Report each MISMATCH path with kind (drift/missing/unreadable).

IF developer asks "show integrity events":
  → tail -n 20 ${CLAUDE_PLUGIN_ROOT}/state/integrity-events.ndjson
  → Highlight HIGH-severity rows; group by path.

IF developer reports an integrity event triggered:
  → Read the event row, get path + kind.
  → Read the file's current bytes; compare semantics to baseline intent.
  → If genuinely adversarial: revert via git or backup, then re-sign.
  → If a legitimate operator edit: re-run sign-state.sh on that path
    to update expected_sigs, document the change.

IF developer wants to install / re-baseline:
  → bash ${CLAUDE_PLUGIN_ROOT}/scripts/sign-state.sh --all
  → This writes sidecar .sig files AND updates baseline.expected_sigs.

IF developer rotates the HMAC key:
  → After setting new HYDRA_STATE_INTEGRITY_HMAC_KEY,
    re-run sign-state.sh --all to refresh signatures.
</decision_tree>

<handoff>
Pairs with hydra-audit-trail and hydra-canary. This plugin is the
defense-of-defense layer (R-020): when those plugins' own state files
are the target of an adversarial Write, this plugin catches it on the
NEXT tool call. It does not replace either; it observes them.
</handoff>

<failure_modes>
- F02 (Fabrication): citing an integrity-event you didn't read. Always
  read the actual NDJSON row.
- F08 (Tool mis-invocation): editing integrity-events.ndjson with Edit.
  The chain breaks. Use Read only.
- F11 (Reward hacking): re-signing AFTER a suspicious diff "to get back
  to green" without investigating what changed. Investigate first, sign
  second.
</failure_modes>
