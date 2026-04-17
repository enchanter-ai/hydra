# vuln-detector

OWASP Top 10 and CWE-mapped vulnerability detection in code changes.

## Install

Part of the [Reaper](../..) bundle. The simplest install is the `full` meta-plugin, which pulls in all 5 Reaper plugins via dependency resolution:

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install full@reaper
```

To install this plugin on its own: `/plugin install reaper-vuln-detector@reaper`. `vuln-detector` flags injection/XSS/SSRF at the code layer — but the same bug pattern often stores credentials (`secret-scanner`), runs them via Bash (`action-guard`), lives in a config file (`config-shield`), and needs to be logged for review (`audit-trail`). On its own, you get one layer of defense-in-depth instead of five.

## Algorithm
- **R3: OWASP Vulnerability Graph** — language-aware pattern matching with CWE mapping

## Hook
- **PostToolUse** on Write/Edit/MultiEdit — scans file content for vulnerability patterns

## Coverage
| OWASP | CWE | Detection |
|-------|-----|-----------|
| A01 | CWE-22 | Path traversal |
| A02 | CWE-327, CWE-338 | Weak crypto |
| A03 | CWE-78, CWE-79, CWE-89 | Injection (SQL, XSS, command) |
| A05 | CWE-346 | CORS misconfiguration |
| A07 | CWE-798 | Hardcoded credentials |
| A08 | CWE-502 | Insecure deserialization |
| A10 | CWE-918 | SSRF |

## Command
`/reaper:vulns` — full OWASP scan with fix suggestions

## Agent
`analyzer` (Sonnet) — deep analysis with false positive detection

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
