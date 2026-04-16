---
name: reaper:secrets
description: >
  Full project scan for secrets, credentials, and API keys.
  Shows findings grouped by severity with masked previews.
---

When the user runs `/reaper:secrets`, perform a comprehensive secret scan.

## Data Source

Read `${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl` and filter for `"event":"secret_detected"` entries.

For a deep scan, also run:
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/pattern-engine.py" .
python3 "${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/entropy-analyzer.py" .
```

## Output Format

```
## Reaper Secret Scan

### Critical ([N])
- **aws-access-key-id** in config.py:12 — masked: `AKIA...WXYZ`
  → Rotate this key immediately. Move to .env file.

### High ([N])
- **github-pat** in deploy.sh:45 — masked: `ghp_...ab12`
  → Rotate token. Use GitHub Actions secrets instead.

### Medium ([N])
- **generic-api-key** in utils.ts:89 — masked: `sk-p...9f3e`
  → Review if this is a real key or placeholder.

### Entropy Findings ([N])
- High-entropy string in .env.example:3 (entropy: 5.2 bits/char)
  → May be a secret not matching known patterns.

Summary: [N] secrets | [N] files | [critical] need rotation
```

## Rules

1. NEVER show full secret values — masked form only (first 4 + last 4 chars).
2. Group by severity: critical first.
3. Include remediation guidance for each finding.
4. Show "No secrets found" if audit.jsonl has no secret_detected events.
5. Use `grep` to pre-filter audit.jsonl — never slurp with `jq -s`.
