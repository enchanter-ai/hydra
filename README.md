# Reaper

An @enchanted-plugins product — algorithm-driven, agent-managed, self-learning.

Named after the **Reaper Leviathan** from Subnautica — you hear it before you see it. It hunts in the dark. Nothing gets past it.

The first security guardrail platform built from real CVEs, real incidents, and real threat intelligence. 5 plugins. 5 agents. 8 named algorithms. One marketplace install.

## The Problem

AI coding agents leak secrets at 3.2x the baseline rate (GitGuardian 2026). They introduce OWASP vulnerabilities without review. They execute destructive commands without confirmation. They trust malicious repository configs blindly.

| Incident | What Happened | CVE |
|---|---|---|
| Check Point hooks exploit | .claude/settings.json ran reverse shell on clone | CVE-2025-59536 |
| API key exfiltration | .claudecode/settings.json stole ANTHROPIC_API_KEY | CVE-2026-21852 |
| 50-subcommand bypass | Commands with 50+ parts skipped ALL deny rules | Adversa AI |
| Clinejection | Prompt injection in Issue title → npm publish of malware | Supply chain |
| Slopsquatting | 20% of AI-suggested packages don't exist | USENIX 2025 |
| Cursor RCE | Prompt injection rewrote ~/.cursor/mcp.json | CVE-2025-54135 |

## How It Works

```
Session Start ──▶ config-shield scans repo configs (R5)
                  ↓
Bash command  ──▶ action-guard classifies (R4+R7) → BLOCK or ALLOW
                  ↓
Write/Edit    ──▶ secret-scanner (R1+R2) → flag secrets
              ──▶ vuln-detector (R3) → flag OWASP vulnerabilities
              ──▶ audit-trail (R8) → log everything
```

## Named Algorithms

| ID | Name | What it catches |
|---|---|---|
| R1 | Aho-Corasick Pattern Engine | 200+ secrets in $O(n+m)$ time |
| R2 | Shannon Entropy Analysis | High-entropy strings ($H > 4.5$) |
| R3 | OWASP Vulnerability Graph | SQL injection, XSS, path traversal, command injection |
| R4 | Markov Action Classification | Dangerous Bash commands classified before execution |
| R5 | Config Poisoning Detection | Malicious repo configs (CVE-2025-59536, CVE-2026-21852) |
| R6 | Phantom Dependency Detection | AI-hallucinated packages (slopsquatting) |
| R7 | Subcommand Overflow Detection | 50+ subcommand deny-rule bypass |
| R8 | Bayesian Threat Convergence | Cross-session security posture tracking |

## Install

```
/plugin marketplace add <path-to-reaper>
```

Or individual plugins:
```
/plugin add <path>/plugins/secret-scanner
/plugin add <path>/plugins/vuln-detector
/plugin add <path>/plugins/action-guard
/plugin add <path>/plugins/config-shield
/plugin add <path>/plugins/audit-trail
```

## Plugin Table

| Plugin | Command | Hook | Agent | Algorithms |
|--------|---------|------|-------|------------|
| secret-scanner | `/reaper:secrets` | PostToolUse (Write/Edit) | scanner (haiku) | R1, R2 |
| vuln-detector | `/reaper:vulns` | PostToolUse (Write/Edit) | analyzer (sonnet) | R3, R6 |
| action-guard | `/reaper:safety` | PreToolUse (Bash) | guardian (sonnet) | R4, R7 |
| config-shield | `/reaper:config-check` | SessionStart | inspector (sonnet) | R5 |
| audit-trail | `/reaper:audit` | PostToolUse (All) | chronicler (haiku) | R8 |

## Comparison

| Feature | Reaper | GitHub Secret Scanning | Snyk | semgrep | Manual Review |
|---------|--------|----------------------|------|---------|---------------|
| Real-time (per-write) | ✓ | ✗ (push only) | ✗ (CI only) | ✗ (CI only) | ✗ |
| Command blocking | ✓ | ✗ | ✗ | ✗ | ✗ |
| Config poisoning | ✓ | ✗ | ✗ | ✗ | Manual |
| Slopsquatting | ✓ | ✗ | Partial | ✗ | ✗ |
| AI-agent aware | ✓ | ✗ | ✗ | ✗ | ✗ |
| Self-learning | ✓ | ✗ | ✗ | ✗ | ✗ |
| Zero dependencies | ✓ (bash + jq) | GitHub | Node | Python | N/A |

## Architecture

See [docs/architecture/](docs/architecture/) for interactive Mermaid diagrams.
See [docs/science/](docs/science/) for all 8 algorithms with LaTeX formulas.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
