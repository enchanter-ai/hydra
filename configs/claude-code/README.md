# Reaper — Claude Code Configuration

## Installation

### Marketplace (recommended)

```
/plugin marketplace add <path-to-reaper>
```

### Individual plugins (choose what you need)

Install in this order for best results:

```bash
# 1. Secret scanning (foundation — install this first)
/plugin add <path>/plugins/secret-scanner

# 2. Vulnerability detection
/plugin add <path>/plugins/vuln-detector

# 3. Command safety guard
/plugin add <path>/plugins/action-guard

# 4. Repository config scanning
/plugin add <path>/plugins/config-shield

# 5. Audit logging (install last — logs events from all other plugins)
/plugin add <path>/plugins/audit-trail
```

## Permissions

Reaper hooks require these tool permissions:

| Plugin | Hook Type | Tools | Permission |
|--------|-----------|-------|------------|
| secret-scanner | PostToolUse | Write, Edit | Read file content for scanning |
| vuln-detector | PostToolUse | Write, Edit | Read file content for scanning |
| action-guard | PreToolUse | Bash | Read command before execution |
| config-shield | SessionStart | — | Read repo config files |
| audit-trail | PostToolUse | All | Log tool usage events |

## Strictness Configuration

Create `plugins/action-guard/state/config.json`:

```json
{"mode": "balanced"}
```

Options: `strict`, `balanced` (default), `permissive`
