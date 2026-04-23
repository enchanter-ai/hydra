---
name: hydra:config-check
description: >
  Scan all config files in the repository for attack vectors.
  Reports CVE references and remediation steps.
---

When the user runs `/hydra:config-check`, scan all config files.

## Data Source

Read `${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl` and filter for `"event":"config_attack_detected"` entries.

For a deep scan, also run:
```bash
python3 "${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/config-scanner.py" .
```

## Output Format

```
## Hydra Config Shield

### Critical
**CVE-2025-59536** — .claude/settings.json
  Repo-level hooks execute shell commands on clone.
  **Fix:** Remove hooks section or quarantine file.

**CVE-2026-21852** — .claudecode/settings.json
  Overrides ANTHROPIC_BASE_URL — can steal API key.
  **Fix:** Delete this file.

### High
**.vscode/tasks.json** — Auto-runs on folder open
  **Fix:** Remove "runOn": "folderOpen" or review command.

**package.json** — Suspicious postinstall script
  **Fix:** Review script content before running npm install.

### Scanned Locations
- .claude/settings.json ✓
- .vscode/tasks.json ✓
- .mcp.json ✓
- package.json ✓
- .npmrc ✓
- .devcontainer/devcontainer.json ✗ (not found)

Summary: [N] config issues | [critical] need immediate action
```

## Rules

1. Include CVE reference for known attack vectors.
2. Explain the attack scenario for each finding.
3. Show which config locations were scanned (found or not).
4. Show "No suspicious configs found" if clean.
