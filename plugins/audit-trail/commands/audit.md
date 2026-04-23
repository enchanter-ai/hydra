---
name: hydra:audit
description: >
  Show the security audit trail filtered by severity, category, or time.
  Generate HTML report for detailed analysis.
---

When the user runs `/hydra:audit`, show the security event timeline.

## Data Source

Read `${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl`. Each line is a JSON object with:
- `event`: event type (secret_detected, vuln_detected, action_blocked, config_attack_detected, tool_use)
- `ts`: ISO 8601 timestamp
- `severity`: critical, high, medium, low, info
- `file`: affected file path (if applicable)
- Plus event-specific fields (pattern_id, cwe, reason, etc.)

## Output Format

```
## Hydra Audit Trail

### Session Summary
| Category | Count |
|----------|-------|
| Secrets | [N] |
| Vulnerabilities | [N] |
| Blocked Actions | [N] |
| Config Warnings | [N] |
| Total Events | [N] |

### Recent Events (last 20)
| Time | Type | Severity | Detail |
|------|------|----------|--------|
| 14:23 | SECRET | critical | aws-access-key-id in config.py:12 |
| 14:25 | VULN | high | CWE-89 in api.py:45 |
| 14:28 | BLOCK | critical | rm -rf / |

### Generate Full Report
Run: python3 shared/scripts/report-gen.py state/audit.jsonl /tmp/hydra-report.html
```

## Rules

1. Show summary counts first, then recent events.
2. Use `tail -n 100` then `grep` — never `jq -s` on audit.jsonl.
3. Sort by timestamp (most recent first) unless user requests otherwise.
4. NEVER show full secret values in audit output.
5. Show "No events logged" if audit.jsonl is empty or missing.
