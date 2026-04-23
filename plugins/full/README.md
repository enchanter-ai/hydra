# full

**Meta-plugin. Installs every Hydra plugin at once.**

This plugin has no hooks, skills, or agents of its own. It exists so you can install the whole 5-plugin defense stack with one command:

```
/plugin marketplace add enchanted-plugins/hydra
/plugin install full@hydra
```

Claude Code resolves the five dependencies and installs:

- `hydra-action-guard` — pre-execution Bash command classifier/blocker
- `hydra-audit-trail` — comprehensive security event logging
- `hydra-config-shield` — session-start repo-config poisoning scanner
- `hydra-secret-scanner` — real-time secret detection in writes
- `hydra-vuln-detector` — OWASP/CWE-mapped vulnerability detection

If you want to cherry-pick a single plugin (e.g. just `hydra-secret-scanner`), you can — but each plugin covers a different attack surface, so you'll typically want defense-in-depth.

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
