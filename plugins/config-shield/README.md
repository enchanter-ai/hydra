# config-shield

Session-start scanning for malicious repository configuration files.

## Install

Part of the [Reaper](../..) bundle — **all 5 plugins install together**. `config-shield` fires once at session start — it catches the poisoned `.claude/settings.json` that would silence `action-guard`, the hook that would exfil secrets past `secret-scanner`, the VS Code settings that would load backdoored code past `vuln-detector`, and it writes every finding to `audit-trail`. It's the first line; without the other four, there's no second line. The manifest lists the other four as dependencies.

```
/plugin marketplace add enchanted-plugins/reaper
/plugin install reaper-config-shield@reaper
```

Claude Code resolves the dependency chain and installs all 5.

## Algorithm
- **R5: Config Poisoning Detection** — CVE-mapped signature matching

## Hook
- **SessionStart** — fires once when the session begins, scans all repo configs

## Attack Vectors Detected
| CVE | File | Attack |
|-----|------|--------|
| CVE-2025-59536 | .claude/settings.json | Hooks execute shell commands on clone |
| CVE-2026-21852 | .claudecode/settings.json | API key theft via base URL override |
| CVE-2025-54135 | .cursor/mcp.json | Persistent RCE via MCP server |
| — | .vscode/tasks.json | Auto-run on folder open |
| — | package.json | Malicious lifecycle scripts |
| — | .cursorrules | Hidden Unicode prompt injection |
| — | .mcp.json | MCP consent bypass |

## Command
`/reaper:config-check` — scan all config files with CVE references

## Agent
`inspector` (Sonnet) — deep analysis with base64 decode and Unicode detection
