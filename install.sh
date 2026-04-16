#!/usr/bin/env bash
# Reaper installer. The 5 plugins are a coordinated bundle — they install
# together or not at all (see .claude-plugin/plugin.json → dependencies).
set -euo pipefail

REPO="https://github.com/enchanted-plugins/reaper"
REAPER_DIR="${HOME}/.claude/plugins/reaper"

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }

step "Reaper installer"

# 1. Clone (or update) the monorepo so shared/*.sh and shared/scripts/*.py are
#    available locally. Plugins themselves are served via the marketplace
#    command below — the clone is just for supporting scripts.
if [[ -d "$REAPER_DIR/.git" ]]; then
  git -C "$REAPER_DIR" pull --ff-only --quiet
  ok "Updated existing clone at $REAPER_DIR"
else
  git clone --depth 1 --quiet "$REPO" "$REAPER_DIR"
  ok "Cloned to $REAPER_DIR"
fi

# 2. Ensure hook scripts are executable (fresh clones on some filesystems lose +x).
chmod +x "$REAPER_DIR"/plugins/*/hooks/*/*.sh 2>/dev/null || true
chmod +x "$REAPER_DIR"/shared/*.sh 2>/dev/null || true
chmod +x "$REAPER_DIR"/shared/scripts/*.py 2>/dev/null || true
ok "Hook scripts marked executable"

cat <<'EOF'

─────────────────────────────────────────────────────────────────────────
  Reaper is a bundle. The 5 plugins layer runtime defenses —
  secret-scanner catches credentials in writes, vuln-detector flags
  OWASP/CWE-mapped code defects, action-guard blocks dangerous Bash,
  config-shield checks repo-level config poisoning at session start,
  and audit-trail logs everything the other four do. Installing only
  one leaves glaring holes in the defense-in-depth stack, so every
  plugin.json lists the other four as dependencies and Claude Code
  pulls them in together.
─────────────────────────────────────────────────────────────────────────

  Finish in Claude Code with TWO commands:

    /plugin marketplace add enchanted-plugins/reaper
    /plugin install reaper-secret-scanner@reaper

  The second command installs all 5 plugins via dependency resolution.
  (Any of the 5 names works — they're peers. secret-scanner is the
  natural entry point since credential leaks are the highest-impact
  catch.)

  Verify with:   /plugin list
  Expected:      5 plugins installed under the reaper marketplace.

EOF
