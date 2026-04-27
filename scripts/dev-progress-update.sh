#!/usr/bin/env bash
# Helper script for /dev skill to create/update dev-progress.json (v5 hardened).
#
# Status: KEPT for backward compatibility but NO LONGER REQUIRED.
# The v5 design treats git log + claudemem notes as ground truth; this helper
# remains for any SKILL that still wants explicit phase tracking.
#
# v5 changes vs v4:
#   - SECURITY: all variables passed via environment to Python, eliminating
#     shell injection via task names or branch names containing quotes.
#   - File locking via flock to prevent concurrent-session corruption.
#
# Usage: dev-progress-update.sh <action> [args...]
#   create <task> <intent> <depth> <branch>
#   phase <phase_name>
#   subtask-add <subtask_name>
#   subtask-done <subtask_name>
#   done
set -euo pipefail

# Branch-scoped progress files for multi-session compatibility.
# Sanitize branch name: replace / with - to avoid path issues.
SAFE_BRANCH=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_DIR=".claude/dev-progress"
PROGRESS_FILE="${PROGRESS_DIR}/${SAFE_BRANCH}.json"
mkdir -p "$PROGRESS_DIR"

ACTION="${1:-}"
shift || true

# Lock file to prevent concurrent-session corruption.
LOCK_FILE="${PROGRESS_FILE}.lock"

run_python() {
  # All Python invocations go through here. Variables come from environment,
  # never interpolated into the script body.
  PROGRESS_FILE_PATH="$PROGRESS_FILE" \
  ARG_TASK="${ARG_TASK:-}" \
  ARG_INTENT="${ARG_INTENT:-}" \
  ARG_DEPTH="${ARG_DEPTH:-}" \
  ARG_BRANCH="${ARG_BRANCH:-}" \
  ARG_PHASE="${ARG_PHASE:-}" \
  ARG_NAME="${ARG_NAME:-}" \
  python3 "$@"
}

case "$ACTION" in
  create)
    export ARG_TASK="${1:-unknown}"
    export ARG_INTENT="${2:-build}"
    export ARG_DEPTH="${3:-default}"
    export ARG_BRANCH="${4:-$(git branch --show-current 2>/dev/null || echo unknown)}"
    (
      flock -x 9
      run_python - <<'PY'
import json, datetime, os
d = {
    '$schema': 'dev-progress-v1',
    'task': os.environ['ARG_TASK'],
    'intent': os.environ['ARG_INTENT'],
    'depth': os.environ['ARG_DEPTH'],
    'phase': 'investigate',
    'started_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'updated_at': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'phases_completed': [],
    'current_subtask': None,
    'subtasks': [],
    'verification': {'tests_pass': None, 'lint_pass': None, 'verify_script_run': False},
    'branch': os.environ['ARG_BRANCH'],
    'files_changed': [],
    'notes': '',
}
with open(os.environ['PROGRESS_FILE_PATH'], 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
print(f"Created: {os.environ['PROGRESS_FILE_PATH']}")
PY
    ) 9>"$LOCK_FILE"
    ;;
  phase)
    export ARG_PHASE="${1:-unknown}"
    (
      flock -x 9
      run_python - <<'PY'
import json, datetime, os
path = os.environ['PROGRESS_FILE_PATH']
new_phase = os.environ['ARG_PHASE']
with open(path, 'r+') as f:
    d = json.load(f)
    old = d.get('phase', '')
    if old and old not in d.get('phases_completed', []):
        d.setdefault('phases_completed', []).append(old)
    d['phase'] = new_phase
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print(f"Phase: {old} -> {new_phase}")
PY
    ) 9>"$LOCK_FILE"
    ;;
  subtask-add)
    export ARG_NAME="${1:-unknown}"
    (
      flock -x 9
      run_python - <<'PY'
import json, datetime, os
path = os.environ['PROGRESS_FILE_PATH']
name = os.environ['ARG_NAME']
with open(path, 'r+') as f:
    d = json.load(f)
    d.setdefault('subtasks', []).append({'name': name, 'status': 'pending'})
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print(f"Subtask added: {name}")
PY
    ) 9>"$LOCK_FILE"
    ;;
  subtask-done)
    export ARG_NAME="${1:-unknown}"
    (
      flock -x 9
      run_python - <<'PY'
import json, datetime, os
path = os.environ['PROGRESS_FILE_PATH']
name = os.environ['ARG_NAME']
with open(path, 'r+') as f:
    d = json.load(f)
    for s in d.get('subtasks', []):
        if s.get('name') == name:
            s['status'] = 'done'
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print(f"Subtask done: {name}")
PY
    ) 9>"$LOCK_FILE"
    ;;
  done)
    (
      flock -x 9
      run_python - <<'PY'
import json, datetime, os
path = os.environ['PROGRESS_FILE_PATH']
with open(path, 'r+') as f:
    d = json.load(f)
    d['phase'] = 'done'
    d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
    f.seek(0)
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.truncate()
print("Task marked done")
PY
    ) 9>"$LOCK_FILE"
    ;;
  *)
    echo "Usage: dev-progress-update.sh <create|phase|subtask-add|subtask-done|done> [args...]" >&2
    exit 1
    ;;
esac
