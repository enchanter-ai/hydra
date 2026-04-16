---
name: config-awareness
description: >
  Use when the developer asks about repository config safety, malicious config files,
  or session-start scan results.
  Auto-triggers on: "config scan", "repo safety", "malicious config",
  "CVE-2025-59536", "config poisoning", "session start scan", "config-check".
allowed-tools:
  - Read
  - Grep
  - Bash
---

<purpose>
Help the developer understand config-shield findings.
Explain attack vectors with CVE references.
Provide remediation steps for each finding type.
</purpose>

<constraints>
1. ALWAYS include CVE reference when applicable.
2. ALWAYS explain the attack scenario — how the config could be exploited.
3. NEVER dismiss config warnings without explanation.
4. Offer to quarantine suspicious files when severity is critical.
</constraints>

<decision_tree>
IF user asks about session-start findings:
  → Read ${CLAUDE_PLUGIN_ROOT}/state/audit.jsonl
  → grep for "config_attack_detected" events
  → Show: file, CVE, severity, description, attack scenario
  → Provide remediation

IF user asks for deep config analysis:
  → Run: python3 ${CLAUDE_PLUGIN_ROOT}/../../shared/scripts/config-scanner.py .
  → Show detailed findings including base64 decode results
  → Check for hidden Unicode characters

IF user asks about a specific CVE:
  → Explain the CVE attack vector
  → Show which config files are affected
  → Provide specific remediation

IF no findings:
  → "No suspicious config files detected at session start."
  → "Config-shield scans: .claude/, .vscode/, .devcontainer/, package.json, .npmrc, .mcp.json"
</decision_tree>

<output_format>
## Config Shield Results

### Critical Findings
**CVE-2025-59536**: .claude/settings.json contains hooks with shell commands
- **File:** .claude/settings.json
- **Attack:** Arbitrary code execution via repo-level hooks on clone
- **Fix:** Remove the hooks section, or review and trust each command explicitly

### High Findings
...

### Remediation Steps
1. Review each flagged file manually
2. Remove or quarantine untrusted config files
3. Report suspicious repos to the platform maintainer
</output_format>

<escalate_to_sonnet>
IF base64-encoded payloads found in config files:
  "ESCALATE_TO_SONNET: obfuscated payload in config — deep decode analysis needed"
IF hidden Unicode characters found:
  "ESCALATE_TO_SONNET: Rules File Backdoor attack pattern — prompt injection analysis needed"
</escalate_to_sonnet>
