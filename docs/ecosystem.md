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
```

## Reaper Plugin Architecture

```
┌────────────────────────────────────────────────────┐
│                    REAPER v1.0.0                    │
│           "You hear it before you see it"           │
│                                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │secret-scanner│  │vuln-detector │  │action-   │ │
│  │ R1: Aho-Cor  │  │ R3: OWASP    │  │guard     │ │
│  │ R2: Shannon  │  │ R6: Phantom  │  │ R4: Markov│ │
│  │ PostToolUse  │  │ PostToolUse  │  │ R7: Overfl│ │
│  └──────────────┘  └──────────────┘  │ PreToolUse│ │
│                                      └──────────┘ │
│  ┌──────────────┐  ┌──────────────┐               │
│  │config-shield │  │ audit-trail  │               │
│  │ R5: Poisoning│  │ R8: Bayesian │               │
│  │ SessionStart │  │ PostToolUse  │               │
│  └──────────────┘  └──────────────┘               │
└────────────────────────────────────────────────────┘
```

## Algorithm Distribution

```
Total: 27+ named algorithms across 8 products

Flux (6):     Gauss ─── SAT ─── Game Theory ─── Adaptation ─── Verification ─── Accumulation
Allay (5):    Markov ─── Runway ─── Shannon ─── Atomic ─── Dedup
Hornet (6):   Bayesian Trust ─── Semantic Diff ─── Info-Gain ─── Continuity ─── Adversarial ─── Learning
Reaper (8):   Aho-Corasick ─── Entropy ─── OWASP ─── Action ─── Config ─── Phantom ─── Overflow ─── Threat
Nook (2):     Exponential Smoothing ─── Budget Boundary
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
