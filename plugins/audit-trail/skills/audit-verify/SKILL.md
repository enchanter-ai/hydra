---
name: audit-verify
description: >
  Verifies the tamper-evidence hash chain on audit-trail's JSONL log.
  Use when the developer asks to verify audit integrity, check whether
  the audit log has been tampered with, validate the hash chain, or
  investigate suspected log manipulation. Auto-triggers on: "verify audit",
  "check audit integrity", "tamper check", "validate hash chain",
  "audit log tampered", "hash chain broken".
allowed-tools:
  - Read
  - Bash
---

<purpose>
Walk the audit-trail JSONL hash chain (prev_hash field per line) and report
whether the log is intact. Each entry's prev_hash must equal
base64(sha256(canonical_json(previous_line))), or "GENESIS" for line 1.
A mismatch signals an in-place edit, deletion, or insertion.
</purpose>

<constraints>
1. Read-only on audit.jsonl. Never repair or rewrite the log — a broken chain
   is forensic evidence; preserve it.
2. Run verify_chain via the shared helper, not a re-implementation. The helper
   is the source of truth for canonicalisation rules.
3. If openssl or jq is missing, report the missing dep — do NOT claim the
   chain is intact.
</constraints>

<decision_tree>
IF user asks to verify the audit log:
  → Run:
    bash -c 'source "${CLAUDE_PLUGIN_ROOT}/scripts/chain-helpers.sh" && verify_chain "${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl"'
  → Exit 0 → report "Chain intact across N lines."
  → Exit 1 → report the offending line number and hashes verbatim from stderr.
  → Exit 2 → report "audit.jsonl not found at expected path."

IF user asks to verify a specific file (not the default audit log):
  → Substitute the path into the same one-liner.

IF user asks "what's in the chain":
  → Read the last 5 lines of audit.jsonl, show event/ts/tool/prev_hash columns.
</decision_tree>

<output_format>
## Audit Chain Verification

- **File:** `<path>`
- **Lines walked:** N
- **Status:** intact | BROKEN at line K
- **Diagnostic** (if broken): `expected <hash> got <hash>`

If broken, recommend: capture a copy of the current audit.jsonl for forensic
review before any further writes, then investigate which event was tampered.
</output_format>

<failure_modes>
- F02 fabrication: never claim "intact" without actually running verify_chain.
- F09 parallel race: a verify run during a heavy tool burst may see a
  partial last line; rerun once the workload settles.
</failure_modes>
