# secret-scanner

Real-time secret detection in every file write. 310+ secret patterns, Shannon entropy analysis, NFA-based pattern matching (with Aho-Corasick on batch path).

## Install

Part of the [Reaper](../..) bundle. The simplest install is the `full` meta-plugin, which pulls in all 5 Reaper plugins via dependency resolution:

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install full@reaper
```

To install this plugin on its own: `/plugin install reaper-secret-scanner@reaper`. `secret-scanner` only catches secrets that land in files — `action-guard` blocks the `cat .env | curl …` exfil path, `config-shield` catches poisoned `.claude/settings.json`, `vuln-detector` flags the code that leaks them, and `audit-trail` is what the incident response team reads afterward. On its own, four other attack surfaces are uncovered.

## Algorithms
- **R1: Multi-Pattern Matching** — grep-based NFA on hooks (<50ms); compiled Aho-Corasick automaton on batch scanning
- **R2: Shannon Entropy Analysis** — high-entropy string detection (>4.5 bits/char)

## Hook
- **PostToolUse** on Write/Edit/MultiEdit — scans file content in <50ms

## Severity Levels
- **CRITICAL:** Private keys, connection strings with credentials
- **HIGH:** API keys, tokens (AWS, GitHub, Anthropic, OpenAI)
- **MEDIUM:** High-entropy strings, generic key assignments
- **INFO:** Findings in test/fixture files (auto-reduced)

## Command
`/reaper:secrets` — full project scan with remediation guidance

## Agent
`scanner` (Haiku) — deep scan using pattern-engine.py and entropy-analyzer.py

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
