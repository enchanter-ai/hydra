#!/bin/sh
# agent-foundations installer
#
# One-liner (vendored install at ./shared/foundations):
#   curl -fsSL https://raw.githubusercontent.com/enchanter-ai/agent-foundations/main/install.sh | sh
#
# With options:
#   curl -fsSL https://raw.githubusercontent.com/enchanter-ai/agent-foundations/main/install.sh | sh -s -- --mode starter
#   ./install.sh --target vendor/foundations --mode minimal
#   ./install.sh --submodule

set -eu

REPO_URL="https://github.com/enchanter-ai/agent-foundations.git"
TARGET="shared/foundations"
MODE="full"
SUBMODULE=0

usage() {
  cat <<'EOF'
agent-foundations installer

Usage:
  install.sh [--target DIR] [--mode MODE] [--submodule]

Options:
  --target DIR    Where to install. Default: shared/foundations
  --mode MODE     Which surfaces to keep:
                    full     all conduct + engines + taxonomy + recipes + docs (default)
                    starter  conduct/ + taxonomy/ + glossary + anti-patterns
                    minimal  conduct/ only
  --submodule     Install as a git submodule (history preserved, pinned via parent repo).
                  Default is a vendored copy with .git stripped — easier to drop into any project.
  -h, --help      Show this message and exit.

Examples:
  install.sh
  install.sh --mode starter
  install.sh --target vendor/foundations --mode minimal
  install.sh --submodule
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)    TARGET="${2:?--target requires a value}"; shift 2 ;;
    --mode)      MODE="${2:?--mode requires a value}"; shift 2 ;;
    --submodule) SUBMODULE=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    *)           printf 'Unknown option: %s\n\n' "$1" >&2; usage >&2; exit 1 ;;
  esac
done

case "$MODE" in
  full|starter|minimal) ;;
  *) printf 'Invalid --mode: %s (expected: full | starter | minimal)\n' "$MODE" >&2; exit 1 ;;
esac

if ! command -v git >/dev/null 2>&1; then
  printf 'git is required but not installed.\n' >&2
  exit 1
fi

if [ -e "$TARGET" ]; then
  printf 'Target already exists: %s\nRemove it or pass a different --target.\n' "$TARGET" >&2
  exit 1
fi

PARENT_DIR=$(dirname -- "$TARGET")
[ -n "$PARENT_DIR" ] && mkdir -p -- "$PARENT_DIR"

if [ "$SUBMODULE" -eq 1 ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' '--submodule requires running inside a git repo.' >&2
    exit 1
  fi
  printf 'Adding submodule at %s ...\n' "$TARGET"
  git submodule add "$REPO_URL" "$TARGET" >/dev/null
else
  printf 'Cloning into %s ...\n' "$TARGET"
  git clone --depth 1 --quiet "$REPO_URL" "$TARGET"
  rm -rf -- "$TARGET/.git"
fi

# Trim per mode
case "$MODE" in
  starter)
    rm -rf -- "$TARGET/engines" "$TARGET/recipes" "$TARGET/docs"
    ;;
  minimal)
    rm -rf -- "$TARGET/engines" "$TARGET/taxonomy" "$TARGET/recipes" "$TARGET/docs"
    rm -f  -- "$TARGET/anti-patterns.md" "$TARGET/glossary.md"
    ;;
esac

# Compute install kind for the success line
KIND="vendored"
[ "$SUBMODULE" -eq 1 ] && KIND="submodule"

cat <<EOF

Installed agent-foundations at $TARGET (mode: $MODE, $KIND).

Next steps:
  1. Reference modules from your CLAUDE.md, system prompt, or .cursor/rules:
       @$TARGET/conduct/discipline.md
       @$TARGET/conduct/verification.md
       @$TARGET/conduct/tool-use.md

  2. Pick a recipe for your host:
       https://github.com/enchanter-ai/agent-foundations/tree/main/recipes
EOF
