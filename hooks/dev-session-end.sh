#!/usr/bin/env bash
# Stop hook: persist dev-progress.json timestamp on session end.
# Part of /dev v4 workflow system. Compatible with Opus 4.6/4.7.
# Obsolescence condition: when session state is managed by Claude Code natively.
set -euo pipefail

# Branch-scoped progress files for multi-session compatibility
BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_DIR=".claude/dev-progress"
PROGRESS_FILE="${PROGRESS_DIR}/${BRANCH}.json"
if [[ ! -f "$PROGRESS_FILE" ]]; then
  PROGRESS_FILE=".claude/dev-progress.json"
fi
if [[ ! -f "$PROGRESS_FILE" ]]; then
  exit 0
fi

python3 -c "
import json, datetime
try:
    with open('$PROGRESS_FILE', 'r+') as f:
        d = json.load(f)
        d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        f.seek(0)
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.truncate()
except Exception:
    pass
" 2>/dev/null || true

exit 0
