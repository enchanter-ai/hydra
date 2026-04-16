---
name: audit-awareness
description: >
  Use when the developer asks about audit logs, security events, session history,
  or wants to generate a security report.
  Auto-triggers on: "audit log", "security events", "what happened",
  "security report", "show audit", "event history", "compliance".
allowed-tools:
  - Read
  - Grep
  - Bash
---

<purpose>
Help the developer review the security event timeline.
Generate reports and summaries from audit data.
Filter and search audit logs by severity, type, or time.
</purpose>

<constraints>
1. NEVER show full secret values in audit output — only masked form.
2. ALWAYS sort by severity (critical first) unless user requests time order.
3. Use tail -n on audit.jsonl — never slurp with jq -s.
4. Offer to generate HTML report for detailed analysis.
</constraints>

<decision_tree>
IF user asks for audit summary:
  → Read last 50 lines of ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl
  → Group by event type: secrets, vulns, blocks, configs, tool_use
  → Show counts and most recent findings

IF user asks to filter by severity:
  → grep for matching severity in audit.jsonl
  → Show filtered results

IF user asks for full report:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/report-gen.py ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl /tmp/reaper-report.html
  → Tell user: "Report generated at /tmp/reaper-report.html"

IF user asks about threat posture:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/learnings.py ${CLAUDE_PLUGIN_ROOT}/state/ --report
  → Show posture score, chronic patterns, top threats

IF audit is empty:
  → "No security events logged yet. Events are recorded as you work."
</decision_tree>

<output_format>
## Security Audit Trail

### Session Summary
- Events logged: [N]
- Secrets detected: [N] (critical: [N])
- Vulnerabilities: [N]
- Blocked actions: [N]
- Config warnings: [N]

### Recent Events (last 10)
| Time | Type | Severity | Detail |
|------|------|----------|--------|
| 14:23 | SECRET | critical | AWS key in config.py:12 |
| 14:25 | VULN | high | CWE-89 SQL injection in api.py:45 |
| 14:28 | BLOCK | critical | rm -rf / blocked |

### Threat Posture
Score: [0.0-1.0] — [CLEAN/CAUTION/WARNING/CRITICAL]
</output_format>

<escalate_to_sonnet>
IF audit trail shows escalating threat pattern:
  "ESCALATE_TO_SONNET: increasing threat rate across session — trend analysis needed"
</escalate_to_sonnet>
