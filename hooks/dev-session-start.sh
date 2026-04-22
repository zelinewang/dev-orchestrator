#!/usr/bin/env bash
# SessionStart hook: inject dev-progress.json into additionalContext
# Part of /dev v4 workflow system. Compatible with Opus 4.6/4.7.
# Obsolescence condition: when models reliably infer workflow state from git log alone.
set -euo pipefail

# Branch-scoped progress files for multi-session compatibility
BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_DIR=".claude/dev-progress"
PROGRESS_FILE="${PROGRESS_DIR}/${BRANCH}.json"
# Fallback: check legacy single-file location
if [[ ! -f "$PROGRESS_FILE" ]]; then
  PROGRESS_FILE=".claude/dev-progress.json"
fi
if [[ ! -f "$PROGRESS_FILE" ]]; then
  exit 0
fi

CONTEXT=$(python3 -c "
import json, datetime, sys
try:
    with open('$PROGRESS_FILE') as f:
        d = json.load(f)
    ts = datetime.datetime.fromisoformat(d.get('updated_at', '2000-01-01T00:00:00+00:00'))
    now = datetime.datetime.now(datetime.timezone.utc)
    age_hours = (now - ts).total_seconds() / 3600
    if age_hours > 24:
        sys.exit(0)
    subtasks = d.get('subtasks', [])
    done = len([s for s in subtasks if s.get('status') == 'done'])
    total = len(subtasks)
    print(f'Resuming /dev task: {d.get(\"task\", \"unknown\")}. '
          f'Phase: {d.get(\"phase\", \"unknown\")}. '
          f'Intent: {d.get(\"intent\", \"unknown\")}. '
          f'Depth: {d.get(\"depth\", \"default\")}. '
          f'Branch: {d.get(\"branch\", \"unknown\")}. '
          f'Progress: {done}/{total} subtasks. '
          f'Read .claude/dev-progress.json for full state.')
except Exception:
    sys.exit(0)
" 2>/dev/null || true)

if [[ -n "$CONTEXT" ]]; then
  python3 -c "
import json, sys
ctx = sys.stdin.read().strip()
if ctx:
    print(json.dumps({'hookSpecificOutput': {'additionalContext': ctx}}))
" <<< "$CONTEXT"
fi
exit 0
