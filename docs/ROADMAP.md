# Reaper Development Roadmap

**Vision:** Build the most comprehensive security guardrail system for AI-assisted development. 8 named algorithms, 5 plugins, real-time protection backed by real CVEs.

## Phases

```
Phase 1 (NOW)          Phase 2               Phase 3               Phase 4
Core scanning          Active protection     Supply chain          MCP integration
secret + vuln + audit  action + config       phantom deps          cross-plugin intel
```

---

## Phase 1: Core Scanning (Foundation)

Real-time detection of secrets and vulnerabilities in every file write.

| Plugin | Algorithm | Status |
|--------|-----------|--------|
| secret-scanner | R1: Aho-Corasick, R2: Shannon Entropy | Shipped |
| vuln-detector | R3: OWASP Vulnerability Graph | Shipped |
| audit-trail | R8: Bayesian Threat Convergence | Shipped |

### Milestone
- 200+ secret patterns with grep-based <50ms matching
- OWASP Top 10 coverage with CWE mapping
- JSONL audit logging with 10MB rotation
- Dark-themed HTML security reports

---

## Phase 2: Active Protection

Pre-execution blocking and session-start scanning.

| Plugin | Algorithm | Status |
|--------|-----------|--------|
| action-guard | R4: Markov Classification, R7: Overflow Detection | Shipped |
| config-shield | R5: Config Poisoning Detection | Shipped |

### Milestone
- Dangerous command blocking (exit 2) with configurable strictness
- Subcommand overflow detection (Adversa AI bypass)
- CVE-mapped config scanning at session start
- Base64 payload decoding and hidden Unicode detection

---

## Phase 3: Supply Chain Intelligence

Package verification and hallucination detection.

| Feature | Algorithm | Target |
|---------|-----------|--------|
| Registry verification | R6: Phantom Dependency Detection | Q3 2026 |
| Levenshtein typosquat | R6 extended | Q3 2026 |
| Live npm/PyPI queries | R6 online | Q4 2026 |

### Milestone
- Cross-reference imports against live package registries
- Detect packages with <100 downloads or <30 days old
- Flag Levenshtein distance ≤2 from popular packages
- Integration with slopsquatting research databases

---

## Phase 4: MCP Integration

Cross-plugin threat intelligence via enchanted-mcp.

| Feature | Target |
|---------|--------|
| Reaper ↔ Hornet: risky change → auto security scan | Q4 2026 |
| Reaper ↔ Allay: threat detection → token budget alert | Q4 2026 |
| Shared threat intelligence across developers | Q1 2027 |
| Real-time security dashboard | Q1 2027 |

---

## Algorithm Registry

| ID | Name | Product | Engine |
|----|------|---------|--------|
| R1 | Aho-Corasick Pattern Engine | Reaper | Multi-pattern O(n+m) matching |
| R2 | Shannon Entropy Analysis | Reaper | High-entropy string detection |
| R3 | OWASP Vulnerability Graph | Reaper | CWE-mapped pattern scanning |
| R4 | Markov Action Classification | Reaper | Command risk classification |
| R5 | Config Poisoning Detection | Reaper | CVE-mapped config scanning |
| R6 | Phantom Dependency Detection | Reaper | Levenshtein typosquat detection |
| R7 | Subcommand Overflow Detection | Reaper | Deny-rule bypass prevention |
| R8 | Bayesian Threat Convergence | Reaper | Cross-session EMA posture |

---

## Timeline

| Phase | Milestone | Target |
|-------|-----------|--------|
| 1 | Core scanning (3 plugins) | Q2 2026 |
| 2 | Active protection (5 plugins) | Q2 2026 |
| 3 | Supply chain intelligence | Q3 2026 |
| 4 | MCP integration | Q4 2026 |

*This is a living document. Update as algorithms evolve and threats emerge.*
