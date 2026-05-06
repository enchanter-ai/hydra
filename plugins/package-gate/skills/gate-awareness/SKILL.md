---
name: gate-awareness
description: >
  Helps the developer interpret package-gate advisory findings and decide
  whether to proceed with a package install. Use when the developer asks
  about a package-gate warning, supply-chain risk on a specific package,
  slopsquat / typosquat / maintainer-churn / download-cliff signals, or
  whether an `npm install` / `pip install` / `pnpm add` / `yarn add` /
  `uv add` target is safe. Auto-triggers on: "is X safe to install",
  "package-gate flagged", "typosquat", "slopsquat", "supply-chain risk",
  "should I install", "this package looks suspicious".
  Do not use for: post-install vulnerability scans (see vuln-detector),
  secrets in installed code (see secret-scanner), or actually blocking
  installs — package-gate is advisory only and the install was not
  blocked.
allowed-tools:
  - Read
  - Bash
  - Grep
---

<purpose>
Translate advisory output from package-gate into a clear go / no-go
recommendation. The hook injects findings into the conversation as
`=== package-gate (advisory) ===` blocks. This skill explains what
each signal means and what the developer should do next.
</purpose>

<constraints>
1. NEVER claim a package is malicious — package-gate findings are
   probabilistic risk signals, not verdicts.
2. NEVER block or refuse the install; package-gate is advisory by
   design (per shared/foundations/conduct/hooks.md). Recommend, do not gate.
3. NEVER fabricate registry data — if metadata is missing, say so.
4. ALWAYS show severity, signal name, and recommended next step.
5. ALWAYS recommend the developer verify a flagged package on the
   relevant registry (npmjs.com, pypi.org, etc.) before installing.
</constraints>

<signal_glossary>
- slopsquat-or-typo  — the name resolves to no published package; an
  AI-hallucinated dependency or a transposition typo. HIGH severity.
- typosquat          — Levenshtein <= 2 to a popular package name; risk
  of substitution attack. HIGH severity.
- recent             — first publish < 30 days ago; not enough history
  for community to vet. HIGH severity.
- stale-or-handover  — no release in > 2 years OR missing maintainer
  metadata; risk of abandoned-package takeover. MEDIUM.
- low-adoption       — < 100 weekly downloads; small or fake user base.
  MEDIUM severity.
- unsupported        — ecosystem (cargo / go / gem / bundler) is not yet
  covered by this advisory; user must verify manually. INFO.
</signal_glossary>

<decision_tree>
IF developer asks about a specific gate finding:
  → Identify the package + signal from the advisory block in context.
  → Explain the signal (use signal_glossary).
  → Recommend: check registry page, verify maintainer, look at GitHub
    repo + open issues, prefer a popular alternative if typosquat.

IF developer asks "is X safe":
  → Run: bash ${CLAUDE_PLUGIN_ROOT}/hooks/pretooluse.sh on a synthetic
    `npm install X` payload (or call gate-check.py directly with
    `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/gate-check.py "npm install X"`).
  → Report findings, severity-ordered.
  → Note this is advisory — final call is the developer's.

IF gate flagged but developer wants to proceed anyway:
  → Acknowledge — package-gate does NOT block.
  → Suggest pinning the version, reading the source, sandboxing the
    install (e.g., separate venv / disposable container) for HIGH-sev
    flags.
</decision_tree>

<output_format>
## package-gate findings — <pkg>

**Signal:** <signal-name> (<severity>)
**Reason:** <one-line reason from the advisory block>
**What it means:** <plain-English from signal_glossary>

**Recommended next step:**
- <action 1, e.g. "open https://www.npmjs.com/package/<pkg>">
- <action 2, e.g. "compare against popular alternative '<target>'">
- <action 3 if applicable>

This is advisory; the install was not blocked.
</output_format>
