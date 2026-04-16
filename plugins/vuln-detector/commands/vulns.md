---
name: reaper:vulns
description: >
  Full OWASP vulnerability scan with CWE mapping, severity ranking,
  and specific fix suggestions.
---

When the user runs `/reaper:vulns`, perform a comprehensive vulnerability scan.

## Data Source

Read `${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl` and filter for `"event":"vuln_detected"` entries.

For a deep scan, also run:
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/vuln-scanner.py" .
python3 "${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/supply-chain.py" .
```

## Output Format

```
## Reaper Vulnerability Scan

### A03:2021 — Injection
| File | Line | CWE | Description | Severity |
|------|------|-----|-------------|----------|
| api.py | 45 | CWE-89 | SQL via string concat | Critical |

### A08:2021 — Software Integrity
| File | Line | CWE | Description | Severity |
|------|------|-----|-------------|----------|
| utils.py | 12 | CWE-502 | pickle.loads | Critical |

### Supply Chain (Phantom Dependencies)
| Package | File | Type | Confidence |
|---------|------|------|------------|
| lodahs | app.js | typosquat of lodash | High |

Summary: [N] vulns | [N] CWE types | [N] OWASP categories
```

## Rules

1. Group findings by OWASP category.
2. Include CWE reference for each finding.
3. Show "No vulnerabilities found" if no vuln_detected events exist.
4. For supply chain findings, show the real alternative package name.
