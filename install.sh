#!/usr/bin/env bash
# Hydra installer. The 5 plugins are a coordinated defense stack; the
# `full` meta-plugin pulls them all in via one dependency-resolution pass.
set -euo pipefail

REPO="https://github.com/enchanter-ai/hydra"
HYDRA_DIR="${HOME}/.claude/plugins/hydra"

step() { printf "\n\033[1;36m▸ %s\033[0m\n" "$*"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; }

step "Hydra installer"

# 1. Clone (or update) the monorepo so shared/*.sh and shared/scripts/*.py are
#    available locally. Plugins themselves are served via the marketplace
#    command below — the clone is just for supporting scripts.
if [[ -d "$HYDRA_DIR/.git" ]]; then
  git -C "$HYDRA_DIR" pull --ff-only --quiet
  ok "Updated existing clone at $HYDRA_DIR"
else
  git clone --depth 1 --quiet "$REPO" "$HYDRA_DIR"
  ok "Cloned to $HYDRA_DIR"
fi

# 2. Ensure hook scripts are executable (fresh clones on some filesystems lose +x).
chmod +x "$HYDRA_DIR"/plugins/*/hooks/*/*.sh 2>/dev/null || true
chmod +x "$HYDRA_DIR"/shared/*.sh 2>/dev/null || true
chmod +x "$HYDRA_DIR"/shared/scripts/*.py 2>/dev/null || true
ok "Hook scripts marked executable"

cat <<'EOF'

─────────────────────────────────────────────────────────────────────────
  Hydra ships as 5 plugins layering runtime defenses — secret-scanner,
  vuln-detector, action-guard, config-shield, and audit-trail. The
  `full` meta-plugin lists all five as dependencies so one install
  pulls in the whole defense stack.
─────────────────────────────────────────────────────────────────────────

  Finish in Claude Code with TWO commands:

    /plugin marketplace add enchanter-ai/hydra
    /plugin install full@hydra

  That installs all 5 plugins via dependency resolution. To cherry-pick
  a single plugin instead, use e.g. `/plugin install hydra-secret-scanner@hydra`.

  Verify with:   /plugin list
  Expected:      full + 5 plugins installed under the hydra marketplace.

EOF
