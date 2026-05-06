# FedRAMP System Boundary — enchanter-ai

**Document version:** 1.0
**Date:** 2026-05-05
**Standard:** FedRAMP Rev 5 + NIST SP 800-53r5 + FedRAMP AI Authorization Pilot (2024)
**Scope:** enchanter-ai (formerly enchanted-skills) — agent-substrate plugin ecosystem
**Document type:** System boundary documentation (input to System Security Plan / SSP)
**Status:** **Pre-authorization.** Not yet submitted for FedRAMP authorization. This is boundary documentation suitable for a 3PAO scoping conversation.

---

## 1. System architecture overview

### What enchanter-ai is

enchanter-ai is a developer-side **agent substrate** — a collection of 11 source-code repositories that, installed together, govern the behavior of Anthropic's Claude Code agent. Components install as Claude Code plugins via `install.sh`; each plugin contributes hooks, skills, settings, and state management.

### Deployment model

| Aspect | Status |
|---|---|
| Deployment | **Developer workstation, today.** No cloud-hosted production tenant exists yet. |
| Data residency | All artifacts on developer's local filesystem |
| Multi-tenant | No |
| Customer data ingress | Only via developer-initiated tool calls (WebFetch, file reads, git operations) |
| Customer data egress | Per hydra/egress-shield allowlist; LLM API endpoints (Anthropic) |

**Implication for FedRAMP:** As of 2026-05-05, enchanter-ai is **not** a hosted SaaS and therefore not directly authorizable as a FedRAMP system. This document scopes the boundary **as if** a SaaS deployment were stood up, so that future authorization work has a baseline.

For a federal-customer deployment, the **authorization boundary** would be the cloud-hosted control plane operating these plugins on behalf of the agency, plus the Anthropic API as an external system.

---

## 2. Component inventory

### 2.1 Core repos (in-boundary)

| Repo | Role | Plugin count | Purpose |
|---|---|---|---|
| agent-foundations | Conduct + runbooks + this folder | n/a | Behavioral defaults, taxonomy, runbooks, compliance |
| hydra | Defensive controls | 15 | Audit, capability-fence, egress, secret-scan, vuln, SBOM, license, package-gate, canary, action-guard, config-shield, reach-filter |
| wixie | Prompt engineering lifecycle + inference engine | 9 | Deep research, craft, refine, converge, test, harden, translate, convergence-engine, inference-engine |
| pech | Cost + budget | 7 | Budget watcher, cost tracker, rate-limiter, rate-shield, cost-query, rate-card-keeper, nook-learning |
| sylph | PR + branch + CI workflow | 9 | pr-lifecycle, weaver-gate, weaver-learning, branch-workflow, capability-memory, ci-reader, commit-intelligence, boundary-segmenter |
| lich | Code-review subagent (mantis) | 8 | mantis-core, -python, -typescript, -rubric, -sandbox, -verdict; lich-preference |
| crow | Decision oversight | 4 | decision-gate, trust-scorer, change-tracker, session-memory |
| emu | Context + state | 3 | context-guard, state-keeper, token-saver |
| gorgon | Code analysis | 6 | gorgon-complexity, -deps, -gaze, -hotspots, -learning, -watcher |
| naga | Cross-repo + observability | 6 | naga-cross-repo, -fingerprint, -learning, -observe, -shift, -validate |
| djinn | Drift + intent management | 6 | compact-guard, drift-aligner, drift-learning, intent-anchor, intent-reorient, utterance-rank |

**Total plugins in scope:** ~73 (numbers exclude meta/`full` aggregator plugins per repo).

### 2.2 External dependencies (in-boundary, supply chain)

| Component | Type | Risk control |
|---|---|---|
| Node.js / npm registry packages | Runtime + tooling | hydra/package-gate typosquat check; hydra/license-gate; hydra/vuln-detector; hydra/sbom-emitter |
| Python / PyPI packages | Tooling (inference-engine, scripts) | Same as above |
| Git / GitHub Actions | CI/CD | sylph/pr-lifecycle; CodeQL workflow; Dependabot config |
| Anthropic API (claude.ai/api) | LLM provider | hydra/egress-shield allowlist entry |

### 2.3 External systems (out-of-boundary, connections inventoried)

| System | Direction | Data classification | Connection control |
|---|---|---|---|
| Anthropic Claude API | Outbound | Prompts (potentially CUI in federal deployment) | hydra/egress-shield allowlist; API key isolation |
| GitHub (git ops) | Bidirectional | Source code + configs | OAuth token; sylph/pr-lifecycle |
| npm / PyPI registries | Inbound (package fetch) | Public dependency metadata | hydra/package-gate verification |
| Web fetched by deep-research | Inbound | Public web content | hydra/egress-shield allowlist; `<untrusted_source>` wrapping; per-fetch budget |
| OTLP collector (Sentry/Datadog) | Outbound (planned, F-021/F-024) | Audit telemetry | TLS; auth token; allowlist |

---

## 3. Authorization boundary diagram (text description)

A graphical version reference: `agent-foundations/docs/architecture/highlevel.mmd`. Text rendering of the boundary:

```
+============================================================+
|                AUTHORIZATION BOUNDARY                      |
|  (developer workstation, or — when SaaS — control plane)   |
|                                                            |
|  +----------------------+   +----------------------------+ |
|  |  Claude Code harness |   |  enchanter-ai plugins      | |
|  |  (Anthropic, OOB)    |<--+  (agent-foundations,        | |
|  |                      |   |   hydra, wixie, pech,       | |
|  |  - Tool runtime      |   |   sylph, lich, crow, emu,   | |
|  |  - Hook dispatcher   |   |   gorgon, naga, djinn)       | |
|  |  - Settings.json     |   |                              | |
|  +----------------------+   +----------------------------+ |
|              ^                          |                  |
|              |                          v                  |
|  +-----------+--------------------------+--------------+   |
|  |               Local filesystem (state)              |   |
|  |  - hydra/audit-trail/state/log.jsonl  (HMAC chain)  |   |
|  |  - wixie/inference-engine/state/*    (SPRT catalog) |   |
|  |  - precedent-log.md (per repo)                      |   |
|  |  - prompts/<name>/* (per-prompt artifacts)          |   |
|  +-----------------------------------------------------+   |
|                                                            |
+============================================================+
        |              |              |              |
        v              v              v              v
  Anthropic API   GitHub API     npm / PyPI    OTLP collector
  (external)      (external)     (external)    (external, planned)
```

The Claude Code harness itself is OOB (out-of-boundary) — it is Anthropic's product. enchanter-ai plugins consume harness APIs but do not modify the harness binary.

---

## 4. Information types

| Information type | Sensitivity | Where it flows | Where it lives at rest |
|---|---|---|---|
| User prompts | Up to CUI in federal deployment | Developer → Claude Code harness → Anthropic API | hydra/audit-trail log; wixie/prompts/<name>/ |
| Tool invocations + arguments | Up to CUI | Harness → plugin hooks → audit log | hydra/audit-trail/state/log.jsonl |
| Tool outputs (file content, web content, API responses) | Variable; possibly CUI | Tool → harness → audit log | hydra/audit-trail/state/log.jsonl |
| Source code | Customer IP | Git repo → harness → editor | Customer's git repo (boundary edge) |
| Secrets (API keys, tokens) | Sensitive | Detected by hydra/secret-scanner; never written to logs | Excluded from audit log via redaction |
| Cross-session learnings | Internal evidence | Plugin emits → inference-engine → briefings | wixie/inference-engine/state/* |
| Compliance telemetry | Internal control | Plugin → OTLP exporter (planned) | External OTLP collector |
| SBOM artifacts | Public-disclosable | hydra/sbom-emitter at release | `state/sbom.cdx.json`, release artifact |

---

## 5. NIST SP 800-53 control implementation pointers

### AC-2 — Account Management

**Implementation:** In a SaaS deployment, account management would be the responsibility of the hosting control plane, not enchanter-ai itself. Within enchanter-ai, **subagent identity** is managed:

- Per `shared/conduct/delegation.md`: every subagent is spawned with an explicit tool whitelist and scope fence.
- Per `hydra/plugins/capability-fence/`: the orchestrator enforces the whitelist at PreToolUse.
- Per-plugin settings.json declares granular tool permissions.

**Evidence:** `hydra/plugins/capability-fence/hooks/PreToolUse.sh`; per-plugin `settings.json`.

**Gap:** F-013 multi-tenant identity boundaries; F-010 escape-hatch CI tests.

### AC-6 — Least Privilege

**Implementation:**

- `shared/conduct/delegation.md` § Tool whitelisting per subagent — investigators get Read/Grep/Glob; red-teams never get Write/Edit.
- `shared/conduct/skill-authoring.md` — minimum tool whitelist required in SKILL.md frontmatter.
- `hydra/plugins/capability-fence/` — runtime enforcement.
- `hydra/plugins/action-guard/` — destructive-op confirmation gate (rm, force-push, schema migration, mass rename, publish).

**Evidence:** SKILL.md `tools:` field per plugin; `hydra/plugins/action-guard/hooks/`.

### AU-2 — Event Logging

**Implementation:** `hydra/plugins/audit-trail/scripts/log-event.sh` logs:

- Every tool invocation (PreToolUse + PostToolUse hooks)
- Every hook decision
- Every capability check
- Every policy verdict
- Every destructive-op confirmation

**Format:** JSONL. **Integrity:** HMAC chain — each entry includes HMAC of previous entry.

**Evidence:** `hydra/plugins/audit-trail/state/log.jsonl`.

### AU-12 — Audit Record Generation

**Implementation:** `hydra/plugins/audit-trail/` generates audit records on every governed event. HMAC chain prevents undetected tampering: any entry deletion or modification breaks the chain on next verification.

**Verification:** `hydra/plugins/audit-trail/scripts/verify-chain.sh` (planned — currently manual).

**Gap:** F-021/F-024 — OTLP exporter not yet shipped, so off-host record copy is absent. HMAC chain is local-only today.

### SC-7 — Boundary Protection

**Implementation:**

- `hydra/plugins/egress-shield/` — per-plugin URL allowlist enforced at PreToolUse on WebFetch and Bash (curl/wget detection).
- `hydra/plugins/egress-monitor/` — observe-mode logging of all egress.
- `wixie/plugins/deep-research/` — `<untrusted_source>` wrapping isolates source role; `shared/conduct/web-fetch.md` mandates Haiku-tier-only WebFetch.

**Evidence:** `hydra/plugins/egress-shield/config/allowlist.yaml`; `hydra/plugins/egress-monitor/state/egress.jsonl`.

**Gap:** F-005 — allowlist sparse; not all plugins have explicit allowlists.

### SI-4 — System Monitoring

**Implementation:**

- `hydra/plugins/audit-trail/` — real-time event capture
- `naga/plugins/naga-observe/` — drift detection
- `wixie/plugins/inference-engine/` — Wald SPRT pattern detection across sessions
- `hydra/plugins/canary/` — prompt-injection canary fixtures

**Evidence:** Multiple state files cited in §4.

**Gap:** F-021/F-024 — OTLP exporter; F-011 — paging on HIGH+ events.

---

## 6. Connection inventory

The hydra/egress-shield allowlist becomes the **canonical connection inventory** for FedRAMP. As of 2026-05-05, declared connections:

| Endpoint | Direction | Purpose | Plugin owning the allowlist entry |
|---|---|---|---|
| `https://api.anthropic.com/*` | Outbound | LLM API | wixie, lich, crow (any plugin invoking Claude) |
| `https://api.github.com/*` | Outbound | Git ops via gh CLI | sylph |
| `https://github.com/*` | Outbound | Git fetches | sylph |
| `https://registry.npmjs.org/*` | Outbound | npm package metadata | hydra/package-gate, hydra/sbom-emitter |
| `https://pypi.org/*` | Outbound | Python package metadata | hydra/package-gate, hydra/vuln-detector |
| `https://api.osv.dev/*` | Outbound | Vulnerability feed (planned, F-009) | hydra/vuln-detector |
| `https://*.fsf.org`, `https://spdx.org/*` | Outbound | License metadata | hydra/license-gate |
| Web fetches by deep-research | Outbound | Per-task fetches | wixie/deep-research (Haiku fetcher only) |
| OTLP collector (planned) | Outbound | Telemetry | hydra/audit-trail (planned) |

The **single source of truth** for connections, when fully shipped (F-005), will be:

```
hydra/plugins/egress-shield/config/allowlist.yaml
```

This file will be the artifact a FedRAMP 3PAO consumes during the SC-7 control review.

---

## 7. Continuous monitoring story

### 7.1 Continuous monitoring components

| Component | Frequency | Artifact | Status |
|---|---|---|---|
| Dependabot dependency scanning | Real-time on commit | GitHub security advisories | **Shipped** — `.github/dependabot.yml` per repo |
| GHAS CodeQL static analysis | On PR + nightly | CodeQL alerts | **Shipped** — `.github/workflows/codeql.yml`; F-022 triage in progress |
| OSV-Scanner cron | Daily (planned) | `state/osv-findings.jsonl` | **In progress** — F-009 |
| hydra/audit-trail HMAC chain verification | On-demand | Verification report | **Shipped** — manual verify; cron pending |
| hydra/canary prompt-injection fixtures | On every WebFetch | `canary-results.jsonl` | **Partial** — advisory; F-004 CI gate pending |
| OTLP exporter to Sentry/Datadog | Real-time (planned) | OTLP spans | **In progress** — F-021/F-024 |
| Quarterly self-attestation | Quarterly | This compliance/ folder | **Shipped** — first issuance 2026-05-05 |
| Wald SPRT pattern reconcile | Per-emit + weekly cron | `inference-engine/state/catalog.json` | **Shipped** |
| MTTR runbooks per F-code | On-incident | `agent-foundations/runbooks/F0*.md` | **Shipped** for F01-F21; pager wiring pending (F-011) |

### 7.2 Annual assessment cadence

A FedRAMP authorized system performs annual assessment by a 3PAO. enchanter-ai is **pre-authorization**, but planned cadence post-authorization:

- **Annual:** 3PAO penetration test, control reassessment
- **Quarterly:** Self-attestation refresh (this folder); SBOM regeneration; vuln-detector audit
- **Monthly:** Egress allowlist review; PR-lifecycle audit-trail review
- **Weekly:** Inference-engine reconcile; Dependabot triage; CodeQL alert triage
- **Real-time:** Audit-trail logging; canary firing; capability-fence enforcement

---

## 8. Outstanding gaps — honest list

1. **System type mismatch.** enchanter-ai is currently a developer-workstation install, not a hosted SaaS. FedRAMP authorization requires a hosted system; this document is preparatory.
2. **F-001** SBOM default-off — supply-chain SBOM is opt-in; needs default-on flip.
3. **F-002** No signed artifact provenance (Sigstore/SLSA L3 release pipeline).
4. **F-005** Egress allowlist sparse — connection inventory incomplete.
5. **F-010** Capability-sandbox escape-hatch CI tests absent.
6. **F-013** No multi-tenant rate-limiting — required for any multi-agency SaaS.
7. **F-021/F-024** OTLP exporter not shipped — audit-trail is local-only today.
8. **F-011** No paging on HIGH+ events.
9. **AU-12** off-host audit-record copy absent (depends on F-021).
10. **No external pentest report** — FedRAMP requires 3PAO pentest. Not yet performed.

---

## 9. What's NOT in this document

- A FedRAMP **System Security Plan (SSP)** — that's a 200+ page document specific to a hosted deployment.
- A **3PAO assessment report (SAR)** — requires engaging a 3PAO firm.
- An **Authorization to Operate (ATO)** — issued by a federal agency after SAR review.
- A **Plan of Action and Milestones (POA&M)** — created post-SAR; gaps in §8 are POA&M-shaped but not formal POA&M entries.
- An **external penetration test report** — required for ATO; not yet performed.

This document supports: 3PAO scoping conversations, agency CIO pre-acquisition reviews, gap-analysis for an ATO roadmap, and agency-side security questionnaire response when enchanter-ai is being evaluated for federal-adjacent use.

---

## 10. Cross-references

- NIST AI RMF mapping: [`./nist-ai-rmf.md`](./nist-ai-rmf.md)
- ISO/IEC 42001 mapping: [`./iso-42001.md`](./iso-42001.md)
- SOC 2 mapping: [`./soc2.md`](./soc2.md)
- Closure audit: `wixie/prompts/security-closure/results/synthesis.md`
- Architecture diagram: `agent-foundations/docs/architecture/highlevel.mmd`
- Conduct modules: `agent-foundations/shared/conduct/*.md`

---

## 11. Self-attestation

The maintainer attests that the boundary, components, and connections described above accurately reflect the current state of enchanter-ai as of 2026-05-05. Gaps are honestly disclosed in §8. No FedRAMP authorization has been pursued or granted; this document is suitable for pre-authorization scoping only.

```
Attested by: ________________________   Date: ____________
Title:       ________________________
Organization: enchanter-ai project
```
