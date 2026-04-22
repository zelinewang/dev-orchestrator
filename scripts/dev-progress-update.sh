#!/usr/bin/env bash
# Helper script for /dev skill to create/update dev-progress.json
# Called by AI during /dev workflow phase transitions.
# Usage: dev-progress-update.sh <action> [args...]
#   create <task> <intent> <depth> <branch>
#   phase <phase_name>
#   subtask-done <subtask_name>
#   subtask-add <subtask_name>
#   done
set -euo pipefail

# Branch-scoped progress files for multi-session compatibility
# Branch-scoped: replace / with - in branch name to avoid path issues
BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_DIR=".claude/dev-progress"
PROGRESS_FILE="${PROGRESS_DIR}/${BRANCH}.json"
mkdir -p "$PROGRESS_DIR"

ACTION="${1:-}"
shift || true

case "$ACTION" in
  create)
    TASK="${1:-unknown}"
    INTENT="${2:-build}"
    DEPTH="${3:-default}"
    BRANCH="${4:-$(git branch --show-current 2>/dev/null || echo unknown)}"
    python3 -c "
import json, datetime
d = {
    '\$schema': 'dev-progress-v1',
    'task': '$TASK',
    'intent': '$INTENT',
    'depth': '$DEPTH',
    'phase': 'investigate',
    'started_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'updated_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'phases_completed': [],
    'current_subtask': None,
    'subtasks': [],
    'verification': {'tests_pass': None, 'lint_pass': None, 'verify_script_run': False},
    'branch': '$BRANCH',
    'files_changed': [],
    'notes': ''
}
with open('$PROGRESS_FILE', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
print(f'Created: $PROGRESS_FILE')
"
    ;;
  phase)
    PHASE="${1:-unknown}"
    python3 -c "
import json, datetime
with open('$PROGRESS_FILE', 'r+') as f:
    d = json.load(f)
    old_phase = d.get('phase', '')
    if old_phase and old_phase not in d.get('phases_completed', []):
        d.setdefault('phases_completed', []).append(old_phase)
    d['phase'] = '$PHASE'
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print(f'Phase: {old_phase} → $PHASE')
"
    ;;
  subtask-done)
    NAME="${1:-unknown}"
    python3 -c "
import json, datetime
with open('$PROGRESS_FILE', 'r+') as f:
    d = json.load(f)
    for s in d.get('subtasks', []):
        if s['name'] == '$NAME':
            s['status'] = 'done'
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print(f'Subtask done: $NAME')
"
    ;;
  subtask-add)
    NAME="${1:-unknown}"
    python3 -c "
import json, datetime
with open('$PROGRESS_FILE', 'r+') as f:
    d = json.load(f)
    d.setdefault('subtasks', []).append({'name': '$NAME', 'status': 'pending'})
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print(f'Subtask added: $NAME')
"
    ;;
  done)
    python3 -c "
import json, datetime
with open('$PROGRESS_FILE', 'r+') as f:
    d = json.load(f)
    d['phase'] = 'done'
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print('Task marked done')
"
    ;;
  *)
    echo "Usage: dev-progress-update.sh <create|phase|subtask-done|subtask-add|done> [args...]" >&2
    exit 1
    ;;
esac
