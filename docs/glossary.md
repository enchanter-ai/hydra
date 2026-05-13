# Hydra glossary

Terms of art used across Hydra. Short definitions; the algorithms live in [docs/science/README.md](science/README.md).

## Rule classes

Hydra's rule library is partitioned into classes. Each rule belongs to exactly one class; classes determine which hook fires and how the finding is routed.

| Class | Fires on | Hook | Example |
|-------|----------|------|---------|
| **Config rule** | Session start | `config-shield` | `.claude/settings.json` contains an unexpected hook declaration. |
| **Action rule** | PreToolUse | `action-guard` | Command matches a destructive-op pattern (`rm -rf /`, `git push --force`, `DROP TABLE`). |
| **Secret rule** | PostToolUse (Write / Edit) | `secret-scanner` | Newly-written content contains a matched secret pattern or a high-entropy string. |
| **Vuln rule** | PostToolUse + on-demand scan | `vuln-detector` | Code matches an OWASP / CWE pattern with severity. |
| **Phantom rule** | PostToolUse | audit-trail | An edit that *looks* benign but matches a known obfuscation-to-attack pattern. |
| **Overflow rule** | PostToolUse | audit-trail | A change that exceeds expected size / scope for the stated task. |

Rule classes are a **mutual-exclusion partition** — a rule cannot be both an action rule and a secret rule. If you find a pattern that feels like both, split it.

## Severity

Each finding carries a severity. Severities are advisory (per [../foundations/packages/core/conduct/hooks.md](../../foundations/packages/core/conduct/hooks.md) — hooks inform, never decide), but they shape how the finding is surfaced.

| Severity | Meaning | Surfacing |
|----------|---------|-----------|
| `CRITICAL` | Credential exposure, RCE path, schema-level destructive action. | Loud inline advisory; flagged in audit trail. |
| `HIGH` | High-confidence vuln match, OWASP Top-10 finding, known-bad pattern. | Inline advisory. |
| `MEDIUM` | Pattern match with higher false-positive rate; context-dependent. | Inline advisory. |
| `LOW` | Suggestive pattern; review at convenience. | Audit trail only. |
| `INFO` | Observational — logged, not surfaced. | Audit trail only. |

## Pattern sources

### OWASP LLM Top 10

A curated list maintained by the [OWASP Foundation](https://owasp.org/www-project-top-10-for-large-language-model-applications/). Hydra covers:

| Code | Name | Hydra rule class |
|------|------|-------------------|
| LLM01 | Prompt injection | Action / Phantom |
| LLM02 | Insecure output handling | Action |
| LLM03 | Training data poisoning | Config |
| LLM04 | Model denial of service | Overflow |
| LLM05 | Supply chain vulnerabilities | Config / Vuln |
| LLM06 | Sensitive information disclosure | Secret |
| LLM07 | Insecure plugin design | Config |
| LLM08 | Excessive agency | Action |
| LLM09 | Overreliance | (advisory guidance only) |
| LLM10 | Model theft | Secret |

### CWE

[Common Weakness Enumeration](https://cwe.mitre.org/). Hydra's vuln-detector maps pattern matches to CWE IDs so findings can be deduplicated against scanners a user already runs.

Hydra ships with coverage for **98 CWEs** — see the README badge. The full mapping lives alongside the rule files in each sub-plugin's pattern source.

### MITRE ATT&CK

Not a primary source, but Hydra cross-references high-severity findings to relevant ATT&CK technique IDs (e.g., `T1059` for command injection) in the audit trail, for teams that report upward to a security operations function.

## Pattern-matching primitives

### Aho-Corasick

Multi-pattern string matching with linear-time lookup across thousands of patterns. Used for known-bad strings (API key formats, CVE strings, toxic flags). Derivation: [docs/science/README.md § Aho-Corasick](science/README.md).

### Entropy scoring

Shannon entropy computed per token. High-entropy strings in newly-written files are flagged even when no Aho-Corasick pattern matches — catches novel or scrambled secrets.

## Hooks

### config-shield

SessionStart hook. Scans the repo for repo-level attack vectors: poisoned `.claude/` configs, unexpected hook declarations, suspicious MCP server entries. Advisory — it reports, it does not block.

### action-guard

PreToolUse hook. Classifies the about-to-run action (via the **Action classifier** algorithm) and emits an advisory warning if the match is dangerous. Advisory per the hooks contract — the user or agent decides.

### secret-scanner

PostToolUse on Write / Edit. Aho-Corasick + entropy. Emits an advisory finding; the audit trail logs everything.

### vuln-detector

PostToolUse + on-demand `/vulns`. OWASP + CWE patterns across source files changed in the session.

### audit-trail

PostToolUse catch-all. Logs every security-relevant event — timestamp, class, severity, verdict — for forensic review or compliance reporting.

## Verdicts

Hydra does not issue DEPLOY / HOLD / FAIL like Wixie. It issues **findings**:

| Verdict | Meaning |
|---------|---------|
| `CLEAR` | No rule matched in the examined scope. |
| `ADVISORY` | One or more matches surfaced; nothing blocked. |
| `AUDIT` | Logged-only matches recorded in the audit trail. |

The decision to proceed is always the human's or the orchestrator's — see [../foundations/packages/core/conduct/hooks.md](../../foundations/packages/core/conduct/hooks.md) § Injection over denial.

## See also

- [README.md](../README.md) — what Hydra does end-to-end.
- [docs/getting-started.md](getting-started.md) — 5-minute first run.
- [docs/science/README.md](science/README.md) — derivations for every algorithm referenced here.
- [SECURITY.md](../SECURITY.md) — how to report security issues in Hydra itself.
