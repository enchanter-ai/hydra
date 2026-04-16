# Enchanted Plugins Brand Guide

## Identity

**Tagline:** Algorithm-driven tools for AI-assisted development.

**Three pillars:**
1. **Algorithm-named engines** — every feature backed by formal math
2. **Managed agent networks** — Opus orchestrates, Sonnet executes, Haiku validates
3. **Self-learning systems** — engines improve with every session

## Naming Rules

1. Every plugin is named after a game entity
2. The metaphor must be immediately obvious (Allay collects, Reaper hunts threats)
3. One game per plugin — no repeats except Minecraft (max 2)
4. The name must be short (1-2 syllables preferred), pronounceable, and memorable
5. The game must be well-known (>1M copies sold or cultural impact)

## Plugin Structure Standard

Every @enchanted-plugins product follows this exact structure:

```
<product>/
├── .claude-plugin/marketplace.json
├── plugins/
│   └── <plugin-name>/
│       ├── .claude-plugin/plugin.json
│       ├── skills/<skill>/SKILL.md       # allowed-tools frontmatter required
│       ├── agents/<agent>.md             # model + context: fork + allowed-tools
│       ├── commands/<command>.md          # slash commands
│       ├── hooks/hooks.json              # lifecycle bindings
│       │   └── <hook-point>/<script>.sh
│       ├── state/.gitkeep
│       └── README.md
├── shared/
│   ├── scripts/                          # Python stdlib only
│   └── patterns/                         # JSON pattern databases
├── tests/
│   ├── run-all.sh
│   └── <plugin>/test-*.sh
├── docs/
│   ├── science/README.md                 # LaTeX formulas, named algorithms
│   ├── ecosystem.md                      # visual diagrams, data flow
│   ├── brand-guide.md                    # this file
│   └── ROADMAP.md                        # phased development plan
├── configs/claude-code/README.md
├── install.sh
├── README.md                             # product selling page
├── CONTRIBUTING.md
└── LICENSE
```

## README Standard

Every product README must include:

1. **Header:** "An @enchanted-plugins product — algorithm-driven, agent-managed, self-learning."
2. **Game reference:** explain the name's origin in the first paragraph
3. **Problem statement:** what pain point does this solve, with evidence
4. **Architecture diagram:** ASCII showing the plugin/agent/hook flow
5. **Named algorithms section:** key formulas in GitHub LaTeX (`$$...$$`)
6. **Install:** one-liner marketplace command
7. **Plugin table:** command, function, agent per plugin
8. **Comparison table:** vs competitors with honest feature comparison
9. **Lifecycle diagram:** where this product fits in the full ecosystem
10. **Contributing link**

## Algorithm Naming Convention

Every algorithm follows: `[Method] [Domain] [Action]`

Examples:
- Aho-Corasick Pattern Engine (multi-pattern string matching)
- Shannon Entropy Analysis (information-theoretic secret detection)
- Markov Action Classification (state-based command risk assessment)
- Bayesian Threat Convergence (cross-session security posture tracking)

## Commit Message Standard

```
feat: <what was added>
fix: <what was fixed>
docs: <what was documented>
refactor: <what was restructured>
test: <what was tested>
```

One logical change per commit. Never batch unrelated changes.

## Agent Model Tiers

| Tier | Model | Role | When to use |
|------|-------|------|-------------|
| Orchestrator | Opus | Judgment, design, intent | Main skill that interacts with user |
| Executor | Sonnet | Script execution, analysis | Background deep scanning, context analysis |
| Validator | Haiku | Pass/fail checks, file validation | Quick secret scanning, event logging |

## Report Standard

Every product generates dark-themed single-page HTML reports:
- Background: `#0A0A0A`
- Surface: `#141414`
- Borders: `rgba(255,255,255,0.04)`
- Brand accent: `#f85149` (Reaper red)
- Generated via `report-gen.py`
- Content: severity bars, CWE pills, findings list, verdict with next steps
