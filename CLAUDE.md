# Reaper — What You Need To Know

You have Reaper installed. It guards your session against secrets, OWASP vulnerabilities, dangerous commands, poisoned configs, and hallucinated dependencies — intercepting at write-time and before Bash executes, not after the fact.

**5 plugins. 5 agents. 887 patterns. 8 named algorithms.** Every pattern backed by a real CVE, incident, or research paper.

## What's happening behind the scenes

At session start:
1. **config-shield** scans the repo for malicious config files across 117 signatures — `.claude/settings.json`, `.vscode/tasks.json`, `package.json`, `.npmrc`, `.mcp.json` (R5 — Config Poisoning Detection; CVE-2025-59536, CVE-2026-21852, CVE-2025-54135)

Every time you use Write or Edit:
2. **secret-scanner** runs 310 secret patterns (R1 — Aho-Corasick) + Shannon entropy check `H > 4.5` for unknown high-randomness strings (R2 — Shannon Entropy Analysis)
3. **vuln-detector** scans for 156 CWE-mapped OWASP Top 10 patterns across 7 languages, comment-aware (R3 — OWASP Vulnerability Graph)
4. **phantom-dependency check** (R6) cross-references new imports against 199 known hallucinated/typosquatted packages using Levenshtein distance ≤ 2

Every time you use Bash:
5. **action-guard** (PreToolUse) classifies the command as SAFE / WARN / BLOCK against 105 dangerous-op patterns (R4 — Markov Action Classification). Any command with >50 subcommand separators is blocked before pattern matching (R7 — Subcommand Overflow, Adversa AI bypass)

On every tool call:
6. **audit-trail** logs to `audit.jsonl`. Cross-session EMA updates threat posture (R8 — Bayesian Threat Convergence, α=0.3).

## Severity levels — what they mean

| Severity | Meaning | Your action |
|----------|---------|-------------|
| CRITICAL | Active threat — secrets exposed, dangerous command, malicious config | STOP. Tell the developer immediately. |
| HIGH | Significant risk — API keys, OWASP vulnerabilities, CWE-mapped | Pause and explain |
| MEDIUM | Potential issue — weak patterns, CORS wildcards, typosquat suspicion | Mention to the developer |
| LOW | Minor concern | Note if relevant |
| INFO | Test fixtures, known example values, in-comment matches | Acknowledge only if asked |

Test files (`test|spec|fixture|mock|example` in path) and `false_positive_hints` from pattern definitions auto-reduce severity. AKIAIOSFODNN7EXAMPLE in a test file = INFO, not CRITICAL.

## What you MUST do

1. **When you see `[Reaper]` in stderr**: Acknowledge it. Name what Reaper flagged, the severity, and the category (secret / vuln / command / config / phantom dep). Don't paraphrase it away.

2. **When Reaper says CRITICAL**: Stop. Tell the developer: "Reaper found a critical security issue. Here's what happened and what we should do." Do not continue writing.

3. **When a command is BLOCKED (exit 2)**: Do NOT try to bypass it. Do not split it across subcommands, obfuscate with base64, pipe through unusual shells, or rephrase to dodge the pattern. R7 specifically blocks that strategy. Explain why it was blocked and suggest a safe alternative.

4. **When secrets are found**: NEVER repeat the full secret value in any output — stderr, logs, explanations, reports, commit messages, chat. Only the masked form (`first4...last4`, e.g. `AKIA...MPLE`). Suggest moving the secret to `.env` or a vault. `sanitize.sh::mask_secret()` is the only correct source of the masked value.

5. **When a new dependency is flagged as phantom/typosquat (R6)**: Do not install it. 20% of AI-suggested packages don't exist (USENIX 2025); attackers register those names. Verify the package on its registry and confirm ownership before proceeding.

6. **When config-shield flags a file at session start**: Do not edit around it or silence it. These are real CVEs (59536, 21852, 54135, 54794). Surface the finding and ask how the developer wants to proceed.

7. **When the developer asks "is this safe"**: Check `plugins/audit-trail/state/audit.jsonl`. Give an honest assessment grouped by severity, with CWE/CVE references where applicable. Don't inflate, don't downplay.

8. **When operating in strict mode**: Treat WARN as BLOCK. When in permissive mode, still surface findings — don't pretend they don't exist because the hook didn't block.

## Commands the developer can use

- `/reaper:secrets` — scan for secrets, credentials, API keys (310 patterns + entropy)
- `/reaper:vulns` — OWASP vulnerability scan with CWE mapping (156 patterns)
- `/reaper:safety` — show blocked/warned commands, change strictness mode
- `/reaper:config-check` — scan repository config files for attack vectors (117 signatures)
- `/reaper:audit` — security event timeline + HTML report

## Strictness modes

Reaper runs in **balanced** mode by default. Mode lives in `plugins/action-guard/state/config.json`.

| Mode | Block patterns | Warn patterns | Use when |
|------|---------------|---------------|----------|
| strict | BLOCK | BLOCK | High-security environments, prod-adjacent repos |
| balanced | BLOCK | WARN (stderr) | Default — recommended |
| permissive | WARN | WARN | Trusted code, prototyping |

## State layout

```
plugins/audit-trail/state/audit.jsonl        # all security events (JSONL, 10MB rotation)
plugins/audit-trail/state/metrics.jsonl      # aggregate scan metrics
plugins/secret-scanner/state/audit.jsonl     # secret findings (masked values only)
plugins/action-guard/state/audit.jsonl       # blocked/warned commands
plugins/action-guard/state/config.json       # strictness mode
/tmp/reaper-report.html                       # generated security report
```

## Agent tiers

| Agent | Model | Plugin | Role |
|-------|-------|--------|------|
| scanner | Haiku | secret-scanner | Fast 310-pattern sweep + entropy |
| analyzer | Sonnet | vuln-detector | Context-aware CWE analysis |
| guardian | Sonnet | action-guard | Command classification + judgment calls |
| inspector | Sonnet | config-shield | CVE matching on config files |
| chronicler | Haiku | audit-trail | Log aggregation + HTML report |

Respect the tiering. Vuln analysis needs Sonnet because CWE disambiguation is context-heavy; secret scanning and audit aggregation stay on Haiku.

## What NOT to do

- Don't suppress or dismiss Reaper warnings — they exist because something real happened to a real developer
- Don't log full secret values anywhere — masked form only, always via `sanitize.sh::mask_secret()`
- Don't try to bypass blocked commands with alternative syntax, subcommand splitting, base64 encoding, or shell substitution — R7 specifically catches those evasions
- Don't ignore config-shield warnings about malicious repo files — hook execution on clone is a real attack class
- Don't install a package flagged as phantom/typosquat without verifying its registry ownership
- Don't modify Reaper state files (`audit.jsonl`, `config.json`) to silence findings
- Don't override strict mode to get past a block — escalate to the developer instead
- Don't write secrets to files — use `.env` or environment variables
