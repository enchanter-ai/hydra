---
name: vuln-awareness
description: >
  Use when the developer asks about vulnerabilities, OWASP issues, CWE findings,
  or security weaknesses in their code.
  Auto-triggers on: "vulnerabilities", "OWASP", "CWE", "security issues",
  "SQL injection", "XSS", "is this code safe", "security scan".
allowed-tools:
  - Read
  - Grep
  - Bash
---

<purpose>
Help the developer understand and fix vulnerability findings.
Provide CWE references, OWASP categories, and specific remediation code.
Show before/after fix examples when possible.
</purpose>

<constraints>
1. NEVER fabricate vulnerabilities — only report from audit.jsonl or scanner output.
2. ALWAYS include CWE reference and OWASP category.
3. ALWAYS suggest specific fix with before/after code when possible.
4. Acknowledge that pattern-based scanning may produce false positives.
5. Group findings by OWASP category for clarity.
</constraints>

<decision_tree>
IF user asks about a specific vulnerability:
  → Read ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl
  → grep for "vuln_detected" events with matching CWE
  → Show: CWE, description, file, line, severity
  → Provide specific fix code

IF user asks for full OWASP scan:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/vuln-scanner.py .
  → Group results by OWASP category
  → Show most critical first

IF user asks about supply chain:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/supply-chain.py .
  → Show phantom dependency findings
  → Suggest package verification steps

IF no findings:
  → "No vulnerabilities detected. Reaper monitors Write/Edit for OWASP Top 10 patterns."
</decision_tree>

<output_format>
## Vulnerability Scan Results

### A03:2021 — Injection ([N] findings)
| File | Line | CWE | Description | Severity |
|------|------|-----|-------------|----------|
| ... | ... | CWE-89 | SQL injection via concatenation | Critical |

**Fix:**
```python
# Before (vulnerable):
query = "SELECT * FROM users WHERE id=" + user_id

# After (safe):
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
```

### A07:2021 — Auth Failures ([N] findings)
...

Summary: [N] vulnerabilities | [N] CWE types | [N] files affected
</output_format>

<escalate_to_sonnet>
IF critical injection or deserialization vulnerabilities found:
  "ESCALATE_TO_SONNET: critical injection vulnerability — deep context analysis needed"
IF more than 5 OWASP categories affected:
  "ESCALATE_TO_SONNET: broad vulnerability surface — architectural review needed"
</escalate_to_sonnet>
