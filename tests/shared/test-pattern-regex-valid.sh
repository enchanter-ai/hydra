#!/usr/bin/env bash
# Test: all regex patterns in new files compile without error
# Uses Node.js RegExp which supports lookahead, Unicode, and PCRE-like features
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HYDRA_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PATTERNS_DIR="$HYDRA_ROOT/shared/patterns"

NEW_FILES=(
  cicd-attacks.json container-security.json iac-misconfig.json crypto-weakness.json
  auth-bypass.json ssrf-patterns.json api-security.json ai-agent-attacks.json
  regex-dos.json deserialization.json file-operations.json logging-forgery.json
  prototype-pollution.json dependency-confusion.json header-security.json
)

TOTAL_FAILS=0
for file in "${NEW_FILES[@]}"; do
  FULL="$PATTERNS_DIR/$file"
  RESULT=$(node -e "
    const path = require('path');
    const fs = require('fs');
    const fp = path.resolve(process.argv[1]);
    const data = JSON.parse(fs.readFileSync(fp, 'utf8'));
    let fails = 0;
    for (const entry of data) {
      try {
        new RegExp(entry.pattern);
      } catch (e) {
        console.log('INVALID REGEX in ' + process.argv[2] + ' id=' + entry.id + ': ' + e.message);
        fails++;
        if (fails >= 5) break;
      }
    }
    process.exit(fails > 0 ? 1 : 0);
  " "$FULL" "$file" 2>&1)
  RC=$?
  if [[ $RC -ne 0 ]]; then
    echo "$RESULT"
    TOTAL_FAILS=$((TOTAL_FAILS + 1))
  fi
done

if [[ $TOTAL_FAILS -gt 0 ]]; then
  echo "FAIL: $TOTAL_FAILS files had invalid regex patterns"
  exit 1
fi

exit 0
