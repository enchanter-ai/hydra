# Reaper — What You Need To Know

You have Reaper installed. It guards your session against secrets, vulnerabilities, dangerous commands, and malicious configs.

## What's happening behind the scenes

At session start:
1. **config-shield** scans the repository for malicious config files (CVE-2025-59536, CVE-2026-21852)

Every time you use Write or Edit:
2. **secret-scanner** checks for 200+ secret patterns (API keys, tokens, private keys, connection strings)
3. **vuln-detector** scans for OWASP Top 10 vulnerabilities (SQL injection, XSS, command injection, etc.)

Every time you use Bash:
4. **action-guard** classifies the command. Dangerous commands are BLOCKED (exit 2). Risky commands get warnings.

On every tool call:
5. **audit-trail** logs the event to audit.jsonl for compliance and review.

## Severity levels — what they mean

| Severity | Meaning | Your action |
|----------|---------|-------------|
| CRITICAL | Active threat — secrets exposed, dangerous command, malicious config | STOP and tell the developer immediately |
| HIGH | Significant risk — API keys, OWASP vulnerabilities | Pause and explain to the developer |
| MEDIUM | Potential issue — weak patterns, CORS wildcards | Mention to the developer |
| LOW | Minor concern | Note if relevant |
| INFO | Test fixtures, expected patterns | Acknowledge only if asked |

## What you MUST do

1. **When you see `[Reaper]` in stderr**: Acknowledge it to the developer. Don't ignore it. Say what Reaper flagged and why.

2. **When Reaper says CRITICAL**: Stop what you're doing. Tell the developer: "Reaper found a critical security issue. Here's what happened and what we should do."

3. **When a command is BLOCKED**: Do NOT try to bypass the block. Explain why it was blocked and suggest a safe alternative.

4. **When secrets are found**: NEVER repeat the full secret value. Use only the masked form (first4...last4). Suggest moving the secret to .env or a vault.

5. **When the developer asks "is this safe"**: Check the audit trail at `plugins/audit-trail/state/audit.jsonl`. Give an honest assessment.

## Commands the developer can use

- `/reaper:secrets` — scan for secrets, credentials, API keys
- `/reaper:vulns` — OWASP vulnerability scan with CWE mapping
- `/reaper:safety` — show blocked/warned commands, change strictness mode
- `/reaper:config-check` — scan repository config files for attack vectors
- `/reaper:audit` — show security event timeline and generate report

## Strictness modes

Reaper runs in **balanced** mode by default. The developer can change this:

| Mode | Block patterns | Warn patterns | Use when |
|------|---------------|---------------|----------|
| strict | BLOCK | BLOCK | High-security environments |
| balanced | BLOCK | WARN (stderr) | Default — recommended |
| permissive | WARN | WARN | Trusted code, reduce friction |

## What NOT to do

- Don't suppress or dismiss Reaper warnings
- Don't write secrets to files — use .env or environment variables
- Don't try to bypass blocked commands with alternative syntax
- Don't ignore config-shield warnings about malicious repo files
- Don't log full secret values in any output — masked form only
