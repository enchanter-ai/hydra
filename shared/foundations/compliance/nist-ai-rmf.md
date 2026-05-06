# NIST AI Risk Management Framework — enchanter-ai conformance map

**Document version:** 1.0
**Date:** 2026-05-05
**Scope:** enchanter-ai (formerly enchanted-skills) — 11-repo plugin ecosystem governing Claude Code agent behavior
**Conformance basis:** NIST AI RMF 1.0 (Jan 2023) + Generative AI Profile NIST AI 600-1 (Jul 2024)
**Status:** **Self-attestation, partial conformance.** No third-party audit performed.

---

## 1. Overview

### What NIST AI RMF is

The NIST AI Risk Management Framework is a voluntary, non-regulatory framework that organizes AI risk-management activities across four functions:

| Function | Purpose |
|---|---|
| **GOVERN** | Cultivate a culture of risk management — policies, accountability, oversight |
| **MAP** | Frame context and identify AI risks |
| **MEASURE** | Analyze, assess, benchmark, and monitor AI risk |
| **MANAGE** | Prioritize, respond, and recover from identified risks |

The Generative AI Profile (NIST AI 600-1) overlays GenAI-specific concerns: confabulation, dangerous-content generation, harmful bias, data privacy, information integrity, prompt injection, value chain & component integration.

### Our scope of conformance

enchanter-ai is **agent-substrate infrastructure**, not a deployed AI system itself. We govern the *behavior* of Claude Code agents acting on a developer's behalf. This document maps our controls to the NIST AI RMF functions an enterprise customer would inherit when deploying enchanter-ai.

Inheritance model: **enterprise inherits MAP/MEASURE/MANAGE technical controls from us; GOVERN remains the enterprise's responsibility** (their AI policy, their accountability structure, their staff training).

---

## 2. Per-plugin compliance table

| Plugin (repo/plugin) | Function | Category | Evidence-of-conformance | Gap |
|---|---|---|---|---|
| hydra/audit-trail | MEASURE | MS-2.4 (audit trail) | `hydra/plugins/audit-trail/scripts/log-event.sh` — HMAC-chained append-only log; events on every tool invocation | OTLP exporter not yet shipped (F-021/F-024 in progress) |
| hydra/capability-fence | MANAGE | MG-2.4 (capability sandbox) | `hydra/plugins/capability-fence/` — per-subagent tool whitelist enforced at PreToolUse hook | Runtime escape-hatch tests not in CI (F-010 partial) |
| hydra/canary | MEASURE | MS-2.6 (adversarial testing), MS-2.7 (red-team) | `hydra/plugins/canary/scripts/canary-check.sh` — prompt-injection canary fixtures fired against WebFetch results | Advisory-only; not yet CI-blocking (F-004 in progress) |
| hydra/egress-shield | MANAGE | MG-3.1 (third-party / supply chain), MG-2.1 (resource control) | `hydra/plugins/egress-shield/` — per-plugin URL allowlist; PreToolUse hook on WebFetch | Allowlist enforcement is observe-only in egress-monitor (F-005 in progress) |
| hydra/secret-scanner | MAP | MP-2.3 (data privacy), MP-5.1 (impact on individuals) | `hydra/plugins/secret-scanner/` — pre-commit + pre-tool-call regex sweep | Entropy-based detection deferred |
| hydra/vuln-detector | MEASURE | MS-1.1 (validity & reliability), MS-2.10 (privacy risks) | `hydra/plugins/vuln-detector/` — npm audit + pip-audit at PreToolUse on install commands | OSV-Scanner cron not yet wired (F-009 in progress) |
| hydra/sbom-emitter | GOVERN | GV-1.5 (transparency), GV-6.1 (third-party transparency) | `hydra/plugins/sbom-emitter/` — CycloneDX SBOM on release | Default-off; needs default-on flip (F-001 critical) |
| hydra/license-gate | GOVERN | GV-1.1 (legal compliance), GV-6.1 (third-party) | `hydra/plugins/license-gate/` — denylist enforcement on dependencies | `--fail-on-deny` not wired into release.yml (F-014 partial) |
| hydra/package-gate | MANAGE | MG-3.1 (third-party), MG-3.2 (supply chain) | `hydra/plugins/package-gate/scripts/check-package.sh` — typosquat + age + maintainer signal | Typosquat seed list not registry-derived (F-023 in progress) |
| hydra/action-guard | MANAGE | MG-2.4 (capability), MG-1.3 (response plan) | `hydra/plugins/action-guard/` — destructive-op confirmation gate | Coverage of all destructive ops not exhaustive |
| hydra/config-shield | MANAGE | MG-2.4 (capability) | `hydra/plugins/config-shield/` — settings.json mutation guard | — |
| hydra/reach-filter | MANAGE | MG-2.1 (resource control) | `hydra/plugins/reach-filter/` — file-system reach enforcement | — |
| wixie/prompt-harden | MEASURE | MS-2.6 (adversarial testing — red-team) | `/harden` skill — 12-attack adversarial audit per prompt | Limited to text prompts; image-prompt red-team gap |
| wixie/deep-research | MAP, MEASURE | MP-1.1 (context), MS-1.3 (info integrity) | `<untrusted_source>` wrapping; cite hygiene per `shared/conduct/web-fetch.md` | CI canary harness for indirect injection deferred (F-019 partial) |
| wixie/inference-engine | MEASURE | MS-2.5 (continuous monitoring) | `wixie/plugins/inference-engine/state/artifacts.jsonl` — Wald SPRT + Beta-Binomial over cross-session evidence | Fail-open dropped-event accounting in progress (F-020 partial) |
| wixie/convergence-engine | MEASURE | MS-1.1 (validity), MS-2.5 (monitoring) | `/converge` skill — Gauss convergence on 5-axis scoring with no-regression contract | — |
| sylph/pr-lifecycle | GOVERN, MANAGE | GV-3.2 (oversight), MG-2.2 (incident response) | PR-template + reviewer gating; CI integration | Reviewer-attestation log not exported to OTLP |
| sylph/weaver-gate | MANAGE | MG-2.2 (incident response), MG-3.1 (supply chain) | Pre-merge gate enforcing branch hygiene | — |
| sylph/capability-memory | GOVERN | GV-1.6 (inventory), GV-4.2 (documentation) | Per-plugin capability declarations | — |
| crow/decision-gate | GOVERN | GV-3.2 (oversight), GV-4.1 (workforce) | Human-in-loop confirmation gate for high-stakes decisions | — |
| crow/trust-scorer | MEASURE | MS-1.1 (validity), MS-3.2 (effectiveness) | Per-source trust scoring | — |
| pech/budget-watcher | MANAGE | MG-2.1 (resource control), MG-1.4 (cost) | Per-session token + dollar budget enforcement | — |
| pech/rate-shield | MANAGE | MG-2.1, MG-1.3 | Per-tenant rate limiting at PreToolUse | F-013 — multi-tenant SaaS rate-limiting in progress |
| lich/mantis-sandbox | MANAGE | MG-2.4 (capability sandbox) | Mantis subagent runs in isolated workspace | Container isolation deferred (F-012) |
| djinn/intent-anchor | MAP | MP-1.1 (context framing), MP-2.2 (intended use) | Per-session intent capture | — |
| djinn/drift-aligner | MEASURE | MS-2.5 (continuous monitoring) | Goal-drift detection across long sessions | — |
| naga/naga-cross-repo | MEASURE | MS-2.4 (audit trail), MS-2.5 (monitoring) | Cross-repo change tracking | — |
| naga/naga-fingerprint | MEASURE | MS-1.3 (information integrity) | Artifact fingerprinting for tamper-evidence | — |
| emu/context-guard | MANAGE | MG-2.4 (capability), MG-2.1 (resource) | Context-budget enforcement | — |
| emu/state-keeper | MEASURE | MS-2.4 (audit) | Session state persistence | — |
| gorgon/gorgon-complexity | MEASURE | MS-1.1 (validity) | Cyclomatic + cognitive complexity gates on generated code | — |
| gorgon/gorgon-deps | MEASURE | MS-1.1 (validity) | Dependency-graph analysis | — |
| agent-foundations (this repo) | GOVERN | GV-1.1 (policy), GV-1.2 (accountability), GV-2.1 (training) | `shared/conduct/*.md` modules — coding conduct, verification, doubt engine, delegation, failure modes, tool use, formatting, skill authoring, hooks, precedent, web fetch, inference substrate | — |

---

## 3. Generative AI Profile (NIST AI 600-1) specific mappings

The GenAI Profile names twelve risks. Our coverage:

| GAI Risk | Risk description | enchanter-ai control | Plugin | Status |
|---|---|---|---|---|
| **GAI-1** CBRN information | Confabulation toward dangerous content | wixie/prompt-harden 12-attack red-team includes CBRN refusal probes | wixie/prompt-harden | Partial |
| **GAI-2** Confabulation | Fabricated factual claims | shared/conduct cite hygiene (`url`, `date`, `source_type`, `quote` required); F02 logged on paraphrased quotes | wixie/deep-research | Conformant |
| **GAI-3** Dangerous content | Violent/illegal content generation | wixie/prompt-harden adversarial probes | wixie/prompt-harden | Partial |
| **GAI-4** Data privacy | PII / secret leakage | hydra/secret-scanner pre-tool-call sweep | hydra/secret-scanner | Conformant |
| **GAI-5** Environmental | Compute footprint disclosure | pech/budget-watcher tracks tokens + cost | pech/budget-watcher | Partial — no carbon estimate |
| **GAI-6** Harmful bias | Discriminatory output | wixie/prompt-harden bias-probe attack class | wixie/prompt-harden | Partial |
| **GAI-7** Human-AI configuration | Over-reliance / under-reliance | crow/decision-gate human-in-loop confirmation | crow/decision-gate | Conformant |
| **GAI-8** Information integrity | Misinformation amplification | wixie/deep-research source-role isolation; `<untrusted_source>` wrapping | wixie/deep-research | Partial |
| **GAI-9** Information security | Prompt injection, model exfil | hydra/canary canary fixtures; capability-fence | hydra/canary, hydra/capability-fence | Partial — canary advisory-only |
| **GAI-10** Intellectual property | Copyrighted content emission | hydra/license-gate dependency licensing | hydra/license-gate | Partial — model-output IP not addressed |
| **GAI-11** Obscene content | Adversarial probe coverage | wixie/prompt-harden | wixie/prompt-harden | Partial |
| **GAI-12** Value chain & components | Third-party model + library risk | hydra/sbom-emitter, hydra/vuln-detector, hydra/package-gate | hydra/* | Partial — SBOM default-off |

---

## 4. Specific function mappings called out

### GV-1.1 — Policies aligned to AI risk

**Implementation:** `agent-foundations/shared/conduct/*.md` — twelve conduct modules governing every plugin's behavior:

- `discipline.md` — coding conduct
- `context.md` — attention budget
- `verification.md` — independent checks
- `doubt-engine.md` — adversarial self-check (F01 sycophancy guard)
- `delegation.md` — subagent contracts
- `failure-modes.md` — 14-code taxonomy
- `tool-use.md` — invocation hygiene
- `formatting.md` — per-target format rules
- `skill-authoring.md` — discovery test, frontmatter discipline
- `hooks.md` — advisory-only contract
- `precedent.md` — cross-session failure log
- `web-fetch.md` — external URL handling
- `inference-substrate.md` — cross-session evidence accumulation

These modules are referenced by every plugin's `CLAUDE.md` as load-once shared behavioral defaults. Override clause requires logging.

### MS-2.6 — Adversarial testing

**Implementation:** `wixie/plugins/prompt-harden/` — `/harden` skill runs 12 canonical attack classes (jailbreak, PII extraction, CBRN, indirect injection, format collapse, etc.) per prompt. Output: `audit.json` with pass/fail per attack.

**Gap:** image-prompt red-team coverage; CI-blocking gate for canary results (F-004).

### MS-2.4 — Audit trail

**Implementation:** `hydra/plugins/audit-trail/scripts/log-event.sh` — HMAC-chained append-only log capturing every tool invocation, hook decision, policy verdict, capability check. Tamper-evident via hash chain.

**Gap:** OTLP / Sentry / Datadog span exporter (F-021/F-024 in progress, ~24h).

### MG-2.4 — Capability sandbox

**Implementation:** `hydra/plugins/capability-fence/` — per-subagent tool whitelist enforced at PreToolUse hook. Per `shared/conduct/delegation.md`, every subagent prompt declares scope and the orchestrator restricts tool access.

**Gap:** Runtime escape-hatch tests not yet in CI; container isolation deferred until Docker enters CI (F-010, F-012).

---

## 5. Outstanding gaps — honest list

The security-closure audit (`wixie/prompts/security-closure/results/synthesis.md`) identified 30 closures. Of those, the architectural items still open:

1. **F-001 SBOM default-off** — sbom-emitter ships, but flag is opt-in; EU CRA 2027 procurement requires default-on. **MUST-SHIP, ~12h.**
2. **F-002 Signed artifact provenance** — Sigstore/SLSA L3 release pipeline not yet shared across all 11 repos. **MUST-SHIP, ~24h shared template.**
3. **F-004 Prompt-injection canary CI gate** — canaries currently advisory; need CI-blocking on WebFetch fixtures. **MUST-SHIP, ~20h.**
4. **F-005 Per-plugin egress allowlist** — egress-monitor observes; egress-shield enforces but allowlist is sparse. **MUST-SHIP, ~22h.**
5. **F-010 Runtime capability sandbox tests** — capability-fence ships at PreToolUse, but escape-hatch CI fuzzing absent. **MUST-SHIP.**
6. **F-013 Per-tenant rate limiting** — pech/rate-shield is single-tenant; multi-tenant SaaS gap.
7. **F-019 Indirect-injection CI canary** — `<untrusted_source>` wrapping shipped, but no automated canary harness.
8. **F-021/F-024 OTLP exporter** — HMAC chain is post-hoc; production observability needs structured spans.
9. **F-008 Cross-plugin ABI compatibility tests** — deferred; needs single-source conduct first.
10. **F-012 Container image scan** — deferred; no containers ship yet.

**Production-readiness score:** ~50/100 per synthesis.md. Foundation correct; ~6 months focused work to reach Snyk/Datadog/Anthropic-RSP-aligned production grade.

---

## 6. Self-attestation

The vendor (enchanter-ai project maintainers) attests under self-assessment that:

1. The controls listed in §2 are implemented as described, in the form of code in the cited plugin paths.
2. The gaps listed in §5 are honestly disclosed; no shipped-but-broken claims appear in §2.
3. No third-party NIST AI RMF assessment has been performed. This document is suitable for procurement triage and gap analysis but does not substitute for an independent assessment.
4. Re-attestation cadence: **quarterly**, or upon any material change to the conduct modules in `agent-foundations/shared/conduct/`.

**Maintainer signature line:**

```
Attested by: ________________________   Date: ____________
Title:       ________________________
Organization: enchanter-ai project
```

---

## 7. Cross-references

- ISO/IEC 42001 mapping: [`./iso-42001.md`](./iso-42001.md)
- SOC 2 Trust Services Criteria mapping: [`./soc2.md`](./soc2.md)
- FedRAMP system boundary: [`./fedramp-boundary.md`](./fedramp-boundary.md)
- Source closure audit: `wixie/prompts/security-closure/results/synthesis.md`
- Conduct modules: `agent-foundations/shared/conduct/*.md`
