# Enchanted Plugins Ecosystem Map

## The Five Questions

Every developer asks these during an AI-assisted session. Each question maps to a plugin.

```
┌──────────────────────────────────────────────────────────┐
│                   Developer Session                       │
│                                                          │
│   "What did I say?"        → Flux     (prompts)          │
│   "What did I spend?"      → Allay    (tokens)           │
│   "What just happened?"    → Hornet   (changes)          │
│   "Is it safe?"            → Reaper   (security)         │
│   "What did it cost?"      → Nook     (spend)            │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Plugin Ecosystem (8 games, 0 overlap)

```
                    ┌─────────────────┐
                    │  ENCHANTED MCP   │
                    │  (unified layer) │
                    └────────┬────────┘
                             │
        ┌────────┬───────────┼───────────┬────────┐
        │        │           │           │        │
   ┌────▼───┐ ┌──▼───┐ ┌────▼────┐ ┌───▼────┐ ┌─▼────┐
   │  Flux  │ │Allay │ │ Hornet  │ │ Reaper │ │ Nook │
   │ prompt │ │token │ │ change  │ │security│ │ cost │
   │enchant │ │health│ │ trust   │ │ guard  │ │track │
   └────────┘ └──────┘ └─────────┘ └────────┘ └──────┘
   Minecraft  Minecraft  Hollow      Subnautica  Animal
   enchantment allay     Knight                  Crossing

        ┌────────┬───────────┬───────────┐
        │        │           │           │
   ┌────▼───┐ ┌──▼─────┐ ┌──▼────┐ ┌───▼──────┐
   │ Athena │ │Crucible│ │Assemb-│ │  + 12    │
   │ review │ │ test   │ │ ler   │ │  more    │
   │ judge  │ │ prove  │ │ CI/CD │ │  plugins │
   └────────┘ └────────┘ └───────┘ └──────────┘
   Hades      Terraria    Factorio   Phase 3-4
```

## Data Flow Between Plugins

```
Session Start
     │
     ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Reaper  │───▶│  Flux   │───▶│  Allay  │
│ scans   │    │ crafts  │    │ tracks  │
│ configs │    │ prompt  │    │ tokens  │
└────┬────┘    └────┬────┘    └────┬────┘
     │              │              │
     │         ┌────▼────┐         │
     │         │ Hornet  │         │
     │         │ watches │         │
     │         │ changes │         │
     │         └────┬────┘         │
     │              │              │
     │    ┌─────────▼─────────┐    │
     └───▶│     Nook          │◀───┘
           │  tallies costs   │
           └──────────────────┘
```

## Algorithm Distribution

```
Total: 27 named algorithms across 8 products

Flux (6):     Gauss ─── SAT ─── Game Theory ─── Adaptation ─── Verification ─── Accumulation
Allay (5):    Markov ─── Runway ─── Shannon ─── Atomic ─── Dedup
Hornet (6):   Bayesian Trust ─── Semantic Diff ─── Info-Gain ─── Continuity ─── Adversarial ─── Learning
Reaper (8):   Aho-Corasick ─── Entropy ─── OWASP ─── Action ─── Config ─── Phantom ─── Overflow ─── Threat
Nook (2):     Exponential Smoothing ─── Budget Boundary
Athena (2):   AST Diff ─── Decision Trees
Crucible (1): Genetic Mutation
Assembler (1):Critical Path DAG
```

## Hook Lifecycle Coverage

```
SessionStart  ──▶  Reaper (config-shield: scan for repo-level attacks)

PreToolUse    ──▶  Allay (token-saver: compress output, block dupes)
              ──▶  Reaper (action-guard: block dangerous commands)

PostToolUse   ──▶  Allay (context-guard: drift detection, runway)
              ──▶  Hornet (change-tracker: semantic diff, trust scoring)
              ──▶  Reaper (secret-scanner, vuln-detector, audit-trail)

PreCompact    ──▶  Allay (state-keeper: checkpoint before compaction)
              ──▶  Hornet (session-memory: save continuity graph)
```

## Game Origin Reference

| Game | Plugin | Why this game fits |
|------|--------|-------------------|
| Minecraft | Flux, Allay | Crafting, enchanting, and collecting — the foundation of building something from nothing |
| Hollow Knight | Hornet | A game about exploration where every area hides secrets you must carefully observe to survive |
| Subnautica | Reaper | A game where the ocean is beautiful but the darkness hides creatures that hunt by sound — you're never truly safe |
| Animal Crossing | Nook | A game where every transaction is tracked, every loan is remembered, and the economy is always watching |
| Hades | Athena | A game where gods judge your performance and reward excellence with boons — quality is earned |
| Terraria | Crucible | A game where you forge items in increasingly extreme conditions to prove their worth |
| Factorio | Assembler | A game that IS automation — every machine connects to the next in an optimized pipeline |

## Infrastructure

Beyond the plugins themselves, the ecosystem has one meta-artifact:

| Repo | Role |
|------|------|
| [`enchanted-plugins/schematic`](https://github.com/enchanted-plugins/schematic) | Canonical repo template. Every new sibling is cloned from here. Ships the invariant tree: `.claude-plugin/`, `CLAUDE.md` (8-section canonical shape), 10 `shared/conduct/*.md` behavioral modules, `docs/architecture/` auto-generation pipeline, `plugins/example-subplugin/` skeleton, renderer toolchain, tests scaffold. The template itself is never installed — it exists to be cloned. |

The architectural contract for the template is defined in [brand-guide.md § Plugin Structure Standard](brand-guide.md#plugin-structure-standard).
