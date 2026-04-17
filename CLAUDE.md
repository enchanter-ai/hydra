# Reaper — Agent Contract

Audience: Claude. Reaper intercepts secrets, OWASP vulnerabilities, dangerous commands, poisoned configs, and phantom dependencies — at write-time and before Bash executes, not after. Every rule is anchored in a real CVE, incident, or research paper.

## Shared behavioral modules

These apply to every skill in every plugin. Load once; do not re-derive.

- @shared/conduct/discipline.md — coding conduct: think-first, simplicity, surgical edits, goal-driven loops
- @shared/conduct/context.md — attention-budget hygiene, U-curve placement, checkpoint protocol
- @shared/conduct/verification.md — independent checks, baseline snapshots, dry-run for destructive ops
- @shared/conduct/delegation.md — subagent contracts, tool whitelisting, parallel vs. serial rules
- @shared/conduct/failure-modes.md — 14-code taxonomy for accumulated-learning logs
- @shared/conduct/tool-use.md — tool-choice hygiene, error payload contract, parallel-dispatch rules
- @shared/conduct/skill-authoring.md — SKILL.md frontmatter discipline, discovery test
- @shared/conduct/hooks.md — advisory-only hooks, injection over denial, fail-open
- @shared/conduct/precedent.md — log self-observed failures to `state/precedent-log.md`; consult before risky steps

When a module conflicts with a plugin-local instruction, the plugin wins — but log the override.

## Lifecycle

| Plugin | Hook | Purpose |
|--------|------|---------|
| config-shield | SessionStart | Scan repo configs for CVE-matched attack signatures (R5) |
| action-guard | PreToolUse (Bash) | **Block** dangerous commands (exit 2); subcommand-overflow check (R4, R7) |
| secret-scanner | PostToolUse (Write\|Edit\|MultiEdit) | 310 patterns + Shannon entropy (R1, R2) |
| vuln-detector | PostToolUse (Write\|Edit\|MultiEdit) | OWASP Top 10 / CWE map, 156 patterns (R3) |
| audit-trail | PostToolUse (all tools) | JSONL log + EMA posture (R8) |

## Algorithms

R1 Aho-Corasick Pattern Engine · R2 Shannon Entropy Analysis · R3 OWASP Vulnerability Graph · R4 Markov Action Classification · R5 Config Poisoning Detection · R6 Phantom Dependency Detection · R7 Subcommand Overflow · R8 Bayesian Threat Convergence. Derivations: `docs/science/README.md`.

Pattern databases: **20 files, 2,011 patterns, 98 CWEs.** Original 5 (secrets 310, vulns 156, dangerous-ops 105, config-attacks 117, slopsquatting 199) + 15 new databases: cicd-attacks 130, container-security 113, iac-misconfig 120, crypto-weakness 90, auth-bypass 80, ssrf-patterns 61, api-security 81, ai-agent-attacks 110, regex-dos 44, deserialization 69, file-operations 50, logging-forgery 41, prototype-pollution 35, dependency-confusion 50, header-security 50.

## Behavioral contracts

Markers: **[H]** hook-enforced · **[A]** advisory.

1. **[H] IMPORTANT — Acknowledge every `[Reaper]` stderr.** Name the category (secret / vuln / command / config / phantom dep) and the severity. Do not paraphrase it away.
2. **[H] YOU MUST NOT bypass a BLOCKED command.** action-guard returns exit 2 — the command did not execute. Do not retry with subcommand splitting, base64, shell substitution, or `eval` wrappers. R7 specifically catches those evasions. Explain the block and suggest a safe alternative.
3. **[H] YOU MUST NOT log full secret values.** Anywhere. stderr, chat, logs, reports, commits. Only the masked form (`first4...last4`) via `shared/sanitize.sh::mask_secret()`. This is enforced at the hook layer; defeating it is a contract violation.
4. **[A] STOP on CRITICAL.** Tell the developer: "Reaper found a critical security issue. Here's what happened and what we should do." Do not continue the task until acknowledged.
5. **[A] Verify phantom deps (R6).** If a new import is flagged as phantom/typosquat, do not install. 20% of AI-suggested packages don't exist (USENIX 2025); attackers register them. Verify the package on its registry and confirm ownership first.
6. **[A] Honour config-shield at SessionStart.** If a config file was flagged (CVE-2025-59536, -21852, -54135, -54794), do not edit around it or silence it. Surface and ask.
7. **[A] ESCALATE in strict mode.** If `plugins/action-guard/state/config.json` is `strict`, treat every WARN as BLOCK. In permissive, still surface findings — do not pretend they don't exist because the hook let them through.

## Severity response

| Severity | Trigger | Action |
|----------|---------|--------|
| CRITICAL | Active threat (exposed secret, dangerous cmd, malicious config) | STOP; surface immediately |
| HIGH | API keys, OWASP vulns with CWE | Pause; explain |
| MEDIUM | Weak patterns, CORS wildcards, typosquat suspicion | Mention to developer |
| LOW | Minor concern | Note if relevant |
| INFO | Test fixtures, known examples, in-comment matches | Acknowledge only if asked |

Test files (`test|spec|fixture|mock|example` in path) and `false_positive_hints` from pattern definitions auto-reduce severity. `AKIAIOSFODNN7EXAMPLE` in a test file = INFO, not CRITICAL.

## Strictness modes

| Mode | Block patterns | Warn patterns |
|------|---------------|---------------|
| strict | BLOCK | BLOCK |
| balanced (default) | BLOCK | WARN (stderr) |
| permissive | WARN | WARN |

Mode lives in `plugins/action-guard/state/config.json`.

## State paths

```
plugins/audit-trail/state/audit.jsonl        (append-only, 10MB rotation)
plugins/secret-scanner/state/audit.jsonl     (masked values only)
plugins/action-guard/state/audit.jsonl       (blocked/warned cmds)
plugins/action-guard/state/config.json       (mutable, mode)
/tmp/reaper-report.html                       (generated report)
```

## Agent tiers

All 5 agents in `./plugins/*/agents/*.md` with explicit output contracts. Tiers follow the @enchanted-plugins convention (Orchestrator/Opus, Executor/Sonnet, Validator/Haiku):

- `scanner` (Haiku) · `chronicler` (Haiku) — validators
- `guardian`, `inspector`, `analyzer` (Sonnet) — executors (CWE disambiguation and config-attack assessment need real reasoning)

## Anti-patterns

- **Command-block evasion.** Splitting `rm -rf /` across subcommands, base64-encoding, piping through `eval`, or wrapping in `bash -c`. R7 blocks >50 subcommand separators before pattern match; the evasion adds risk without benefit.
- **Unmasked secret in any output.** Including stderr, chat, reports, commit messages. GitGuardian 2026: Claude-assisted commits leak at 3.2× baseline — the masking contract is the mitigation.
- **Phantom install.** Installing a typosquat or hallucinated package to "unblock" a task. R6 catches edit-distance ≤ 2 typosquats and 199 known hallucinated names across npm / PyPI / Cargo / Go / RubyGems.
- **Config-shield silence.** Editing around a flagged `.claude/settings.json`, `.vscode/tasks.json`, or `.mcp.json` without surfacing. Hook-on-clone is a real attack class (Check Point CVE-2025-59536).
- **State mutation.** Editing `audit.jsonl` or `config.json` to dismiss findings or flip strictness without the developer's say-so. Breaks R8 posture tracking and the strict-mode contract.
