# enchanter-ai Compliance Evidence Package

**Issued:** 2026-05-05
**Maintainer:** enchanter-ai project
**Audience:** Buyer-side auditors, procurement officers, security questionnaire reviewers, CISOs evaluating enchanter-ai for adoption.

---

## What this folder is

This folder is the canonical **compliance evidence package** for enchanter-ai (formerly enchanted-skills) — a four-document mapping of enchanter-ai plugins and controls to four major industry frameworks. It is the artifact a buyer's auditor or procurement team consumes when asking *"is this thing compliant?"*

It is **self-attestation** based on the project's own implementation review and the security-closure audit at `wixie/prompts/security-closure/results/synthesis.md`. **No third-party audit or certification has been obtained for any framework herein.**

---

## What's included

| File | Framework | Use when… |
|---|---|---|
| [`nist-ai-rmf.md`](./nist-ai-rmf.md) | NIST AI Risk Management Framework 1.0 + Generative AI Profile (NIST AI 600-1) | Buyer asks about AI-specific risk-management practices, GenAI risks (confabulation, prompt injection, etc.) |
| [`iso-42001.md`](./iso-42001.md) | ISO/IEC 42001:2023 (AI Management System) | Buyer is in a regulated industry that requires ISO management-system conformance, or is in EU and needs EU AI Act alignment |
| [`soc2.md`](./soc2.md) | SOC 2 Trust Services Criteria (Security + Availability) | Buyer's procurement requires SOC 2; gap-assessment input for Type I/II audit readiness |
| [`fedramp-boundary.md`](./fedramp-boundary.md) | FedRAMP Rev 5 + NIST SP 800-53r5 | Federal agency adoption; ATO scoping; agency CIO security review |

Plus this **README.md** (index + how-to-use guide).

---

## How an auditor would consume this package

### Buyer-side procurement triage (quickest path)

1. Read this README to scope.
2. Read the framework that matches your jurisdiction / customer mandate:
   - US federal → `fedramp-boundary.md`
   - EU / international / ISO-aligned org → `iso-42001.md`
   - Any AI-deploying enterprise → `nist-ai-rmf.md`
   - SOC 2-mandated procurement → `soc2.md`
3. Skip to the **Outstanding gaps** section in each — that's the honest list of what's not yet shipped.
4. Cross-check against `wixie/prompts/security-closure/results/synthesis.md` for the canonical action plan.

### CISO / Security review

1. Start with `nist-ai-rmf.md` for AI-risk posture.
2. Read `soc2.md` for general-purpose security control mapping.
3. Read the closure audit synthesis for the project's own threat model.
4. Trace specific control evidence pointers (cited file paths) into the actual repos.

### 3PAO / external auditor scoping

1. Read `fedramp-boundary.md` first — it scopes the system boundary explicitly.
2. Read `soc2.md` — control mapping is structurally identical.
3. Trace evidence pointers into:
   - `hydra/plugins/audit-trail/` (audit log)
   - `hydra/plugins/egress-shield/config/allowlist.yaml` (connection inventory, when shipped)
   - `wixie/plugins/inference-engine/state/` (continuous monitoring substrate)
   - `agent-foundations/shared/conduct/*.md` (policy)
4. Note: external pentest report and Type II audit report are NOT in this package — those require external auditor engagement.

---

## Which framework applies when

```
                        +----------------------------+
                        |  Are you a federal agency? |
                        +-------+----------+---------+
                                |          |
                              Yes          No
                                |          |
                                v          v
                       +---------------+   +---------------------+
                       | fedramp-      |   | Are you in EU /     |
                       | boundary.md   |   | regulated AI?        |
                       +---------------+   +-------+----------+--+
                                                   |          |
                                                 Yes          No
                                                   |          |
                                                   v          v
                                          +-----------------+ +------------------+
                                          | iso-42001.md +  | | nist-ai-rmf.md + |
                                          | nist-ai-rmf.md  | | soc2.md          |
                                          +-----------------+ +------------------+
```

| You are… | Read |
|---|---|
| US federal agency | `fedramp-boundary.md` (primary), `nist-ai-rmf.md` (supporting) |
| Federal contractor (CMMC adjacent) | `fedramp-boundary.md` + `nist-ai-rmf.md` |
| EU enterprise (EU AI Act prep) | `iso-42001.md` + `nist-ai-rmf.md` |
| ISO-certified org | `iso-42001.md` |
| US enterprise SaaS | `soc2.md` + `nist-ai-rmf.md` |
| Healthcare / regulated AI | All four; `nist-ai-rmf.md` GenAI Profile is most relevant |
| Open-source consumer | `nist-ai-rmf.md` for AI risks; `soc2.md` § Evidence pointers for self-host security |

---

## Honest disclosures

### What the project HAS done

- Implemented 73+ plugins across 11 repos with documented behavioral controls
- Maintained 12 conduct modules under `agent-foundations/shared/conduct/`
- Run a self-driven security-closure audit identifying 30 closures (F-001..F-030)
- Shipped HMAC-chained audit logging, capability-fencing at PreToolUse, secret scanning, vulnerability detection, license gating, SBOM emission, and prompt-hardening adversarial testing
- Built a cross-session inference substrate using Wald SPRT + Beta-Binomial statistics for continuous improvement
- Documented gaps honestly in each framework doc

### What the project HAS NOT done

- **No third-party SOC 2 Type I or Type II audit.** The `soc2.md` document is gap assessment and control documentation, NOT a SOC 2 report.
- **No FedRAMP authorization.** No 3PAO assessment performed; no ATO granted. `fedramp-boundary.md` is pre-authorization scoping documentation.
- **No ISO/IEC 42001 certification.** No certification body assessment performed.
- **No NIST AI RMF independent assessment.** Self-attestation only.
- **No external penetration test.** Required for any production deployment claim; pending.
- **No formal management-review structure.** Project is small-team / single-maintainer today.

### Production-readiness score

Per `wixie/prompts/security-closure/results/synthesis.md`: **~50/100.** Foundation is correct; ~6 months of focused work + harness coordination to reach Snyk/Datadog/Anthropic-RSP-aligned production grade. The MUST-SHIP queue (F-001, F-002, F-004, F-005, F-010, F-013) is ~120 hours of work.

---

## Top outstanding gaps (cross-framework)

These show up across all four documents:

1. **F-001** SBOM default-off — EU CRA 2027 procurement blocker, NIST AI RMF GAI-12 partial, ISO 42001 A.10.2 partial, SOC 2 CC9.2 partial.
2. **F-002** Signed artifact provenance (Sigstore/SLSA L3) absent across the 11 repos.
3. **F-004** Prompt-injection canary CI gate advisory-only — NIST AI RMF MS-2.6 partial, SOC 2 CC6.6 partial.
4. **F-005** Per-plugin egress allowlist sparse — FedRAMP SC-7 partial, SOC 2 CC6.7 partial, ISO 42001 §6.1 partial.
5. **F-010** Runtime capability-sandbox escape-hatch CI tests absent — FedRAMP AC-6 partial, NIST AI RMF MG-2.4 partial, SOC 2 CC6.1 partial.
6. **F-013** Multi-tenant rate-limiting absent — relevant only for SaaS deployment; SOC 2 A1.1 partial.
7. **F-019** Indirect-injection CI canary harness absent — NIST AI RMF GAI-9 partial.
8. **F-021/F-024** OTLP / Sentry / Datadog exporter not shipped — FedRAMP AU-12 partial, SOC 2 CC7.2 partial, ISO 42001 §9.1 partial.
9. **F-011** Paging on HIGH+ events absent — SOC 2 CC7.4 partial.
10. **F-009** OSV-Scanner cron not wired — SOC 2 CC7.1 partial.

For each of these, see the cited framework doc for the per-control treatment and timeline.

---

## What's NOT included in this package

This package does NOT include the following — they require **external** parties:

| Artifact | Why excluded | How to obtain |
|---|---|---|
| External penetration test report | Requires external pentest firm engagement | Engage Bishop Fox, NCC Group, or similar AI-specialist firm |
| SOC 2 Type II audit report | Requires CPA firm + 6-12 month audit period | Engage SOC 2 audit firm after MUST-SHIP queue closes |
| FedRAMP SAR (Security Assessment Report) | Requires 3PAO firm engagement | Engage FedRAMP-accredited 3PAO; preceded by SSP authoring |
| FedRAMP ATO | Issued by federal agency after SAR review | Federal agency sponsorship + SAR review |
| ISO/IEC 42001 certificate | Requires certification body assessment | Engage accredited certification body (BSI, DNV, TÜV) |
| Independent NIST AI RMF assessment | Optional but adds credibility | Engage AI-RMF-experienced consulting firm |

Procurement teams: this package is a **starting point** for diligence. To close diligence for high-stakes (federal, regulated, large-enterprise) deployment, the items above are required.

---

## Re-attestation cadence

These documents are re-attested **quarterly**, or upon any material change to:

- `agent-foundations/shared/conduct/*.md`
- The plugin inventory (new plugins shipped, plugins retired)
- The security-closure audit findings
- The list of external connections in the egress allowlist

Next scheduled re-attestation: **2026-08-05.**

---

## Contact

For procurement diligence, security questionnaires, or 3PAO scoping conversations, contact the project maintainer via the channels listed in `agent-foundations/README.md`.

---

## Versioning

| Version | Date | Notes |
|---|---|---|
| 1.0 | 2026-05-05 | Initial issuance — NIST AI RMF, ISO 42001, SOC 2, FedRAMP boundary docs |

---

## Related resources

- Source closure audit: `wixie/prompts/security-closure/results/synthesis.md`
- Conduct modules: `agent-foundations/shared/conduct/*.md`
- Architecture diagrams: `agent-foundations/docs/architecture/highlevel.mmd`
- Failure-mode taxonomy: `agent-foundations/shared/conduct/failure-modes.md`
- Runbooks: `agent-foundations/runbooks/F0*.md`
