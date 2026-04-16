# config-shield

Session-start scanning for malicious repository configuration files.

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
