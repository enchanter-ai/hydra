#!/usr/bin/env bash
set -euo pipefail

REAPER_DIR="${HOME}/.claude/plugins/reaper"

if [[ -d "$REAPER_DIR" ]]; then
  echo "Reaper already installed at $REAPER_DIR"
  echo "To update: cd $REAPER_DIR && git pull"
  exit 0
fi

echo "Installing Reaper..."
git clone https://github.com/enchanted-plugins/reaper "$REAPER_DIR"
chmod +x "$REAPER_DIR"/plugins/*/hooks/*/*.sh
chmod +x "$REAPER_DIR"/shared/*.sh
chmod +x "$REAPER_DIR"/shared/scripts/*.py

echo ""
echo "Done. Run in Claude Code:"
echo ""
echo "  /plugin add $REAPER_DIR/plugins/secret-scanner"
echo "  /plugin add $REAPER_DIR/plugins/vuln-detector"
echo "  /plugin add $REAPER_DIR/plugins/action-guard"
echo "  /plugin add $REAPER_DIR/plugins/config-shield"
echo "  /plugin add $REAPER_DIR/plugins/audit-trail"
echo ""
echo "Or add the marketplace:"
echo "  /plugin marketplace add $REAPER_DIR"
echo ""
echo "Start with secret-scanner + vuln-detector — they're the foundation."
