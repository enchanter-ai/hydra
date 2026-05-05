# egress-monitor

Advisory PostToolUse logger for network egress. Records every `WebFetch` / `WebSearch` / `Bash`-network destination to an append-only NDJSON log and emits a stderr advisory the first time a host is seen. **Always exits 0; never blocks.**

## Why

Audit finding F-043 flagged the missing per-plugin egress allowlist surface across the ecosystem. This plugin closes the observability slice — every outbound destination is now durably recorded, so a session-by-session answer to *"what did this reach out to?"* exists without digging through transcripts. Allowlist enforcement is intentionally out of scope; advisory observation is the contract.

## Hook

- **PostToolUse** matcher `WebFetch|WebSearch|Bash`.
- **Always exits 0** (per `shared/conduct/hooks.md`). Advisory output goes to stderr; nothing is denied.
- **Pre-filter** in bash: non-network `Bash` returns in ~5ms without invoking python.
- **Latency budget** ~50ms hot path, ~150ms when python runs.

## What gets logged

| Tool | Destination logged | Notes |
|---|---|---|
| `WebFetch` | host of `tool_input.url` | One record per call |
| `WebSearch` | synthetic `websearch` | Only `query_len` is logged; query text is **not** retained |
| `Bash` curl/wget/http | host of every URL in argv | Deduplicated per call |
| `Bash` git push/pull/clone/fetch | `git:<remote-name>` | Remote URL is **never** logged |

Record shape (`state/log.ndjson`):

```json
{"ts":"2026-05-05T12:34:56Z","tool":"WebFetch","host":"example.com","first_seen":true}
```

## First-seen advisory

The first time a host appears in the session that is not already in `state/seen-domains.json`, the hook prints:

```
=== egress-monitor (advisory) ===
First-seen destination: example.com
Review: state/log.ndjson
```

After emission, the host is appended to `state/seen-domains.json` (atomic `os.replace` write). Subsequent calls to that host are still logged but no longer advise.

## Files

```
egress-monitor/
├── .claude-plugin/plugin.json
├── README.md
├── hooks/
│   ├── hooks.json
│   └── posttooluse.sh
├── scripts/egress-log.py
├── skills/egress-awareness/SKILL.md
└── state/
    ├── log.ndjson.gitkeep
    └── seen-domains.json
```

## APIs called

**None.** This plugin makes no outbound network calls; it is local-only logging of others'.

## Skill

`/skill egress-awareness` (Haiku) — summarises `state/log.ndjson` and explains advisory output. Never claims a destination is malicious; first-seen is a recency signal.

## Relationship to other Hydra plugins

- `package-gate` runs **pre-install** advisory checks against package registries.
- `egress-monitor` (this) records **all** outbound destinations after the call.
- They are independent: one inspects what you would install, the other records what you actually contacted.

## Behavioral modules

Inherits the [shared behavioral modules](../../shared/) via root [CLAUDE.md](../../CLAUDE.md) — discipline, context, verification, delegation, failure-modes, tool-use, skill-authoring, hooks.
