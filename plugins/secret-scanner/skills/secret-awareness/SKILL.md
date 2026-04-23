---
name: secret-awareness
description: >
  Use when the developer asks about secrets, credentials, API keys, or tokens
  found in their code, or wants to understand secret scanning results.
  Auto-triggers on: "found secrets", "are there secrets", "credential scan",
  "API key detected", "what secrets", "leaked keys", "scan for secrets".
allowed-tools:
  - Read
  - Grep
  - Bash
---

<purpose>
Help the developer understand and remediate secret findings.
Translate raw audit data into actionable remediation guidance.
NEVER display full secret values — only masked form (first4...last4).
</purpose>

<constraints>
1. NEVER display or reproduce full secret values — only masked form.
2. NEVER fabricate findings — only report from audit.jsonl data.
3. ALWAYS show severity level and remediation guidance.
4. ALWAYS mention .env or vault-based alternatives when suggesting fixes.
5. Reduce severity to INFO for test/fixture/example files.
</constraints>

<decision_tree>
IF user asks about a specific secret finding:
  → Read ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl
  → grep for "secret_detected" events
  → Filter to relevant file
  → Show: pattern_id, severity, masked value, line number
  → Suggest remediation: move to .env, use vault, rotate key

IF user asks for full scan:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/pattern-engine.py .
  → Show summary grouped by severity and category
  → Prioritize critical findings first

IF user asks about entropy findings:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/entropy-analyzer.py <file>
  → Show: high-entropy strings with entropy score
  → Explain: "These strings have high randomness (>4.5 bits/char) and may be secrets"

IF no findings:
  → "No secrets detected. Hydra monitors every Write/Edit for 200+ patterns."
</decision_tree>

<output_format>
## Secret Scan Results

### Critical ([N] findings)
| File | Line | Pattern | Masked | Action |
|------|------|---------|--------|--------|
| ... | ... | ... | ... | Rotate + move to .env |

### High ([N] findings)
...

### Medium ([N] findings)
...

Summary: [N] secrets found | [N] files affected | [critical count] need immediate rotation
</output_format>

<escalate_to_sonnet>
IF more than 10 distinct secret types found:
  "ESCALATE_TO_SONNET: complex secret remediation plan needed"
IF secrets found in production config files:
  "ESCALATE_TO_SONNET: production secret exposure — incident response guidance needed"
</escalate_to_sonnet>
