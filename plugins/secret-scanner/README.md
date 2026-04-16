# secret-scanner

Real-time secret detection in every file write. 200+ patterns, Shannon entropy analysis, Aho-Corasick matching.

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
