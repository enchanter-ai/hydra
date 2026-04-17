# full

**Meta-plugin. Installs every Reaper plugin at once.**

This plugin has no hooks, skills, or agents of its own. It exists so you can install the whole 5-plugin defense stack with one command:

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install full@reaper
```

Claude Code resolves the five dependencies and installs:

- `reaper-action-guard` — pre-execution Bash command classifier/blocker
- `reaper-audit-trail` — comprehensive security event logging
- `reaper-config-shield` — session-start repo-config poisoning scanner
- `reaper-secret-scanner` — real-time secret detection in writes
- `reaper-vuln-detector` — OWASP/CWE-mapped vulnerability detection

If you want to cherry-pick a single plugin (e.g. just `reaper-secret-scanner`), you can — but each plugin covers a different attack surface, so you'll typically want defense-in-depth.

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks, precedent.
