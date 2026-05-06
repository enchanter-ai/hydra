# SOC 2 Trust Services Criteria — enchanter-ai control mapping

**Document version:** 1.0
**Date:** 2026-05-05
**Standard:** AICPA SOC 2 — Trust Services Criteria (TSC) 2017 + 2022 revisions
**Scope:** enchanter-ai (formerly enchanted-skills) — 11-repo agent-substrate plugin ecosystem
**Type:** Pre-audit gap assessment / Type II readiness
**Status:** **Not yet audited.** This document is internal control documentation, not a SOC 2 report.

---

## 1. Trust criteria scope

A SOC 2 engagement covers some or all of five Trust Services Criteria:

| TSC | Status | Rationale |
|---|---|---|
| **Security** (Common Criteria) | **In scope** | Mandatory baseline |
| **Availability** | **In scope** | Substrate uptime relevant for cross-session continuity |
| Confidentiality | Documented (in scope when SaaS deployment lands) | Currently developer-local; no multi-tenant data |
| Privacy | Out of scope | No PII processed by the substrate itself |
| Processing Integrity | Documented (in scope when SaaS deployment lands) | HMAC-chained audit log demonstrates integrity controls |

This document maps **CC1 through CC9 (Common Criteria — Security)** plus **A1 (Availability)** to enchanter-ai controls.

A formal SOC 2 audit requires:
1. An independent CPA firm engagement
2. A defined audit period (Type II = 6-12 months operating effectiveness)
3. Evidence collection during that period
4. The CPA firm's report

This document is **input** to that engagement, not a substitute.

---

## 2. CC1 — Control Environment

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC1.1 | Demonstrates commitment to integrity & ethics | Conduct modules: `discipline.md`, `verification.md`, `doubt-engine.md` | `agent-foundations/shared/conduct/` | **Ready** |
| CC1.2 | Board oversight | **GAP** — no formal board structure | — | **Not ready** — single-maintainer org |
| CC1.3 | Management establishes structures, reporting lines | Tier model (Opus/Sonnet/Haiku) per CLAUDE.md; per-plugin owner field | `*/CLAUDE.md`, `*/plugins/*/.claude-plugin/plugin.json` | **Partial** |
| CC1.4 | Commitment to attract/develop competent individuals | Skill-authoring discipline, conduct training material | `shared/conduct/skill-authoring.md` | **Ready** |
| CC1.5 | Holds individuals accountable | Failure-mode logging, learnings.md, override-must-be-logged contract | `shared/conduct/failure-modes.md` | **Ready** |

---

## 3. CC2 — Communication and Information

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC2.1 | Quality information for internal control | Per-plugin metadata.json; learnings.md; precedent-log.md | `wixie/prompts/<name>/`, `state/precedent-log.md` | **Ready** |
| CC2.2 | Internal communication | Cross-session briefings via inference-engine substrate | `wixie/plugins/inference-engine/state/briefings/` | **Ready** |
| CC2.3 | External communication | This compliance/ folder; per-repo READMEs | `agent-foundations/compliance/`, `*/README.md` | **Ready** |

---

## 4. CC3 — Risk Assessment

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC3.1 | Specifies suitable objectives | DEPLOY bar: σ<0.45, overall≥9.0, all axes≥7.0, 8/8 SAT | `wixie/CLAUDE.md` § DEPLOY bar | **Ready** |
| CC3.2 | Identifies and analyzes risk | Security-closure audit (F-001..F-030) + SPRT-elevated patterns | `wixie/prompts/security-closure/results/synthesis.md` | **Ready** |
| CC3.3 | Assesses fraud risk | hydra/secret-scanner; HMAC-chained audit log (tamper detection) | `hydra/plugins/secret-scanner/`, `hydra/plugins/audit-trail/` | **Ready** |
| CC3.4 | Assesses change-related risk | Convergence loop with no-regression contract; baseline-snapshot per `verification.md` | `wixie/plugins/convergence-engine/`, `shared/conduct/verification.md` | **Ready** |

---

## 5. CC4 — Monitoring Activities

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC4.1 | Selects, develops, performs evaluations | Quarterly self-attestation; security-closure audits; SPRT reconcile | `compliance/*.md`, `inference-engine.py reconcile` | **Partial** — first SPRT cycle |
| CC4.2 | Communicates deficiencies | Failure-mode log; precedent log; gap sections in this folder | `shared/conduct/failure-modes.md`, `state/precedent-log.md` | **Ready** |

---

## 6. CC5 — Control Activities

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC5.1 | Selects/develops control activities | Conduct modules; per-plugin SKILL.md runbooks | `shared/conduct/`, `*/plugins/*/SKILL.md` | **Ready** |
| CC5.2 | Selects/develops technology controls | Hydra defensive plugins (audit-trail, capability-fence, egress-shield, secret-scanner, vuln-detector, package-gate, license-gate, sbom-emitter) | `hydra/plugins/*` | **Partial** — F-001/F-002/F-004/F-005/F-010 in progress |
| CC5.3 | Deploys via policies and procedures | Lifecycle stages; install.sh; settings.json wiring | `*/install.sh`, `wixie/CLAUDE.md` § Lifecycle | **Ready** |

---

## 7. CC6 — Logical and Physical Access Controls

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC6.1 | Logical access security software | hydra/capability-fence (per-subagent tool whitelist); hydra/action-guard (destructive-op confirm) | `hydra/plugins/capability-fence/`, `hydra/plugins/action-guard/` | **Partial** — escape-hatch tests not in CI (F-010) |
| CC6.2 | New users authorized; access modified | Skill-discovery test gates new skills; per-plugin settings.json permissions | `shared/conduct/skill-authoring.md` | **Ready** |
| CC6.3 | User access provisioning | Per-tool whitelist in subagent prompt per `delegation.md` | `shared/conduct/delegation.md` | **Ready** |
| CC6.4 | Physical access | N/A — distributed code repository, no physical infrastructure under our control | — | **N/A** |
| CC6.5 | Disposal of physical assets | N/A | — | **N/A** |
| CC6.6 | External threat protection | hydra/egress-shield (URL allowlist); hydra/canary (prompt-injection canaries); `<untrusted_source>` wrapping | `hydra/plugins/egress-shield/`, `hydra/plugins/canary/`, `wixie/plugins/deep-research/` | **Partial** — canary advisory-only (F-004) |
| CC6.7 | Restricts data movement | hydra/egress-shield allowlist | `hydra/plugins/egress-shield/` | **Partial** — sparse allowlist (F-005) |
| CC6.8 | Controls to prevent/detect malicious software | hydra/package-gate (typosquat + age + maintainer); hydra/vuln-detector (npm audit + pip-audit) | `hydra/plugins/package-gate/scripts/check-package.sh`, `hydra/plugins/vuln-detector/` | **Partial** — typosquat seed list not registry-derived (F-023) |

---

## 8. CC7 — System Operations

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC7.1 | Detection of vulnerabilities | hydra/vuln-detector; Dependabot config; CodeQL workflow | `hydra/plugins/vuln-detector/`, `*/.github/workflows/codeql.yml` | **Partial** — OSV-Scanner cron not yet wired (F-009) |
| CC7.2 | Detection of anomalies | hydra/audit-trail HMAC chain; naga/naga-observe drift detection; inference-engine SPRT | `hydra/plugins/audit-trail/scripts/log-event.sh`, `wixie/plugins/inference-engine/` | **Partial** — OTLP exporter pending (F-021/F-024) |
| CC7.3 | Evaluates security events | F-code triage per `failure-modes.md`; runbooks F01-F21 | `shared/conduct/failure-modes.md`, `agent-foundations/runbooks/` | **Ready** |
| CC7.4 | Responds to security incidents | hydra/action-guard destructive-op gate; pager.ts (F-011 in progress) | `hydra/plugins/action-guard/` | **Partial** — pager not yet shipped |
| CC7.5 | Recovers from identified incidents | Convergence loop revert-on-regression; precedent log of dead-ends | `wixie/plugins/convergence-engine/`, `state/precedent-log.md` | **Ready** |

---

## 9. CC8 — Change Management

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC8.1 | Authorizes, designs, develops, configures, documents, tests, approves, implements changes | sylph/pr-lifecycle; sylph/weaver-gate; convergence loop with baseline snapshot | `sylph/plugins/pr-lifecycle/`, `sylph/plugins/weaver-gate/` | **Ready** |
| CC8.1 (sub) | Tests changes | wixie/prompt-tester regression suite (≥3 tests, ≥1 edge-case per prompt) | `wixie/plugins/prompt-tester/` | **Ready** |
| CC8.1 (sub) | Approves changes | Convergence verdict (DEPLOY / HOLD / FAIL); reviewer Haiku-tier validator | `wixie/plugins/convergence-engine/`, `wixie/CLAUDE.md` § DEPLOY bar | **Ready** |

---

## 10. CC9 — Risk Mitigation

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| CC9.1 | Identifies, selects, develops risk mitigation activities | Closure audit MUST-SHIP / HIGH-CONFIDENCE / DEFERRED queues | `wixie/prompts/security-closure/results/synthesis.md` | **Ready** |
| CC9.2 | Vendor and business partner risk | hydra/sbom-emitter; hydra/license-gate; hydra/package-gate; hydra/vuln-detector | `hydra/plugins/sbom-emitter/`, `hydra/plugins/license-gate/`, `hydra/plugins/package-gate/`, `hydra/plugins/vuln-detector/` | **Partial** — SBOM default-off (F-001) |

---

## 11. A1 — Availability

| Criterion | Description | enchanter-ai control | Evidence pointer | Readiness |
|---|---|---|---|---|
| A1.1 | Capacity for processing demand | pech/budget-watcher; pech/rate-shield; emu/context-guard | `pech/plugins/budget-watcher/`, `pech/plugins/rate-shield/`, `emu/plugins/context-guard/` | **Partial** — multi-tenant rate-limiting gap (F-013) |
| A1.2 | Backup and recovery | Inference-engine append-only log; precedent log committed to git | `wixie/plugins/inference-engine/state/artifacts.jsonl`, `state/precedent-log.md` | **Ready** |
| A1.3 | Tests recovery procedures | **GAP** — no formal recovery drill schedule | — | **Not ready** |

---

## 12. Evidence pointers (which plugin produces which artifact)

| Artifact | Producer | Path |
|---|---|---|
| HMAC-chained audit log | hydra/audit-trail | `hydra/plugins/audit-trail/scripts/log-event.sh` → `state/log.jsonl` |
| Tool-whitelist enforcement | hydra/capability-fence | `hydra/plugins/capability-fence/hooks/PreToolUse.sh` |
| Egress allowlist | hydra/egress-shield | `hydra/plugins/egress-shield/config/allowlist.yaml` |
| Secret-scan results | hydra/secret-scanner | `hydra/plugins/secret-scanner/state/findings.jsonl` |
| Vulnerability findings | hydra/vuln-detector | `hydra/plugins/vuln-detector/state/audit.jsonl` |
| SBOM (CycloneDX) | hydra/sbom-emitter | `hydra/plugins/sbom-emitter/state/sbom.cdx.json` |
| License findings | hydra/license-gate | `hydra/plugins/license-gate/state/findings.jsonl` |
| Typosquat / package risk | hydra/package-gate | `hydra/plugins/package-gate/scripts/check-package.sh` |
| Destructive-op confirmations | hydra/action-guard | `hydra/plugins/action-guard/state/confirmations.jsonl` |
| Prompt-injection canary results | hydra/canary | `hydra/plugins/canary/state/canary-results.jsonl` |
| Per-prompt audit (12-attack red-team) | wixie/prompt-harden | `wixie/prompts/<name>/audit.json` |
| Per-prompt regression tests | wixie/prompt-tester | `wixie/prompts/<name>/tests.json` |
| Convergence learnings | wixie/convergence-engine | `wixie/prompts/<name>/learnings.md` |
| Cross-session pattern catalog | wixie/inference-engine | `wixie/plugins/inference-engine/state/catalog.json` |
| Per-plugin briefings | wixie/inference-engine | `wixie/plugins/inference-engine/state/briefings/<plugin>.md` |
| PR lifecycle records | sylph/pr-lifecycle | `sylph/plugins/pr-lifecycle/state/` |
| Decision-gate confirmations | crow/decision-gate | `crow/plugins/decision-gate/state/decisions.jsonl` |
| Precedent log (operational gotchas) | All plugins | `state/precedent-log.md` per repo |

---

## 13. Type II audit readiness assessment

| Trust Criterion | Readiness | Blocker(s) |
|---|---|---|
| CC1 Control Environment | **Partial** | CC1.2 board oversight — single-maintainer org |
| CC2 Communication | **Ready** | — |
| CC3 Risk Assessment | **Ready** | — |
| CC4 Monitoring | **Partial** | First-cycle SPRT data; need 6-12mo evidence period |
| CC5 Control Activities | **Partial** | F-001/F-002/F-004/F-005/F-010 in progress |
| CC6 Logical Access | **Partial** | CC6.1 escape-hatch tests, CC6.6/6.7 canary CI gate + allowlist density |
| CC7 System Operations | **Partial** | CC7.1 OSV-Scanner, CC7.2 OTLP, CC7.4 pager |
| CC8 Change Management | **Ready** | — |
| CC9 Risk Mitigation | **Partial** | F-001 SBOM default-on |
| A1 Availability | **Partial** | A1.1 multi-tenant rate-limiting; A1.3 recovery drill schedule |

**Overall:** Type II audit-ready in **~6 months** after MUST-SHIP queue closure (F-001, F-002, F-004, F-005, F-010, F-013) plus 6-month evidence collection period running on the closed controls.

**Type I (point-in-time)** readiness target: **~3 months** after MUST-SHIP closure.

---

## 14. Outstanding gaps — honest list

1. **CC1.2** — No board / formal oversight structure. Deferred until org formalizes.
2. **CC5.2 / CC6.1** — F-010 capability-sandbox escape-hatch CI tests absent.
3. **CC6.6 / CC6.7** — F-005 egress allowlist sparse; F-004 canary CI-blocking gate not wired.
4. **CC6.8** — F-023 typosquat seed list not registry-derived.
5. **CC7.1** — F-009 OSV-Scanner cron not wired.
6. **CC7.2** — F-021/F-024 OTLP exporter not shipped.
7. **CC7.4** — F-011 pager.ts not shipped.
8. **CC9.2** — F-001 SBOM default-off (EU CRA 2027 procurement blocker).
9. **A1.1** — F-013 multi-tenant rate-limiting absent.
10. **A1.3** — No formal recovery-drill schedule.

---

## 15. Cross-references

- NIST AI RMF mapping: [`./nist-ai-rmf.md`](./nist-ai-rmf.md)
- ISO/IEC 42001 mapping: [`./iso-42001.md`](./iso-42001.md)
- FedRAMP boundary: [`./fedramp-boundary.md`](./fedramp-boundary.md)
- Closure audit: `wixie/prompts/security-closure/results/synthesis.md`

---

## 16. What's NOT in this document

- A SOC 2 Type I or Type II report — those require an independent CPA firm engagement.
- An attestation that controls operated effectively over a defined period — that requires Type II audit evidence collection.
- A management assertion letter — drafted at audit engagement, not in this gap-assessment doc.

This document is **gap assessment + control documentation** suitable for: procurement triage, SOC 2 audit-readiness scoping, and customer security-questionnaire responses citing implemented controls.
