# secret-scanner

Real-time secret detection in every file write. 200+ patterns, Shannon entropy analysis, Aho-Corasick matching.

## Install

Part of the [Reaper](../..) bundle — **all 5 plugins install together**. `secret-scanner` only catches secrets that land in files — `action-guard` blocks the `cat .env | curl …` exfil path, `config-shield` catches poisoned `.claude/settings.json`, `vuln-detector` flags the code that leaks them, and `audit-trail` is what the incident response team reads afterward. Installing it alone leaves four other attack surfaces uncovered. The manifest lists the other four as dependencies.

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install reaper-secret-scanner@reaper
```

Claude Code resolves the dependency chain and installs all 5.

## Algorithms
- **R1: Aho-Corasick Pattern Engine** — O(n+m) multi-pattern scanning via grep
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
