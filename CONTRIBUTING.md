# Contributing to Reaper

## Stack

bash + jq only for hooks. No Node.js. No external APIs.
Python stdlib is OK for non-time-critical scripts (analysis, reports, learnings).

## Critical Rules

Before submitting a PR, verify:

1. **Never use `flock`** — macOS doesn't have it. Use atomic `mkdir` for locks.
2. **Never use `$CLAUDE_SESSION_ID`** for cache keys — doesn't reset after /clear.
3. **Never use `jq -s`** on growing files — slurps entire file into RAM. Safe on bounded inputs.
4. **Every hook has `trap 'exit 0' ERR INT TERM`** — hooks must never break Claude.
5. **64KB stdout limit** — write large output to tmpfiles under `/tmp/reaper-*`.
6. **Validate JSON before parsing** with `jq empty`.
7. **Block URL-encoded path traversal** — decode `%2e%2e` before checking.
8. **Rotation at 10MB** not 1MB.
9. **Use `jq -n --arg`** for JSON construction — never printf/sed chains.
10. **NEVER log actual secret values** — masked form only (first 4 + last 4 chars).

## Security-Specific Rules

11. **Every pattern addition needs positive AND negative test cases.**
12. **All CWE/CVE references must be verified** against official databases.
13. **False positive hints are required** for every secret pattern.
14. **Secret masking is enforced** — `mask_secret()` in sanitize.sh, `mask_value()` in Python.
15. **action-guard is the ONLY hook that may exit 2** — all others exit 0 always.

## Code Style

- `shellcheck -x` passes on all `.sh` files
- Use `printf "%s"` over `echo` for variable content
- Use `local` for function variables
- Quote all variable expansions (`"$var"` not `$var`)
- Use `[[ ]]` over `[ ]` for conditionals
- Use `$(command)` over backticks
- Keep hook scripts under 200 lines

## Testing

```bash
bash tests/run-all.sh
```

Tests pipe mock JSON to hooks via stdin and verify exit codes and output.
Tests must clean up all temp files and state files after running.

## Adding a Pattern

1. Add to the appropriate file in `shared/patterns/`:
   - `secrets.json` — secret patterns
   - `vulns.json` — vulnerability patterns (must include CWE)
   - `dangerous-ops.json` — command patterns (action: block or warn)
   - `config-attacks.json` — config file patterns (include CVE if known)
   - `slopsquatting.json` — hallucinated package names

2. Each pattern needs:
   - Unique `id`
   - Valid regex `pattern`
   - `severity` level
   - For secrets: `false_positive_hints` array
   - For vulns: `cwe` and `owasp` references
   - For commands: `action` (block or warn)

3. Add test cases in `tests/<plugin>/test-*.sh`

## Adding a Plugin

```
plugins/<name>/
├── .claude-plugin/plugin.json
├── skills/<skill>/SKILL.md
├── agents/<agent>.md
├── commands/<command>.md
├── hooks/
│   ├── hooks.json
│   └── <hook-point>/<script>.sh
├── state/.gitkeep
└── README.md
```

Register in `.claude-plugin/marketplace.json`.

## Submitting

1. `shellcheck -x` passes on all `.sh` files
2. `tests/run-all.sh` exits 0
3. No banned patterns (`flock`, `jq -s` on unbounded files)
4. Every SKILL.md has `allowed-tools` frontmatter
5. Every agent has `model`, `context: fork`, and `allowed-tools`
6. Secret values are NEVER logged in any form
7. New patterns have corresponding positive and negative tests
