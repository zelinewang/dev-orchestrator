#!/usr/bin/env bash
# SessionStart hook (v5): inject ground-truth context for autonomous workflow.
#
# Compared to v4: instead of relying on self-reported dev-progress.json (which
# is empty across all worktrees because the SKILL never wired up the writer),
# this version reads git/claudemem ground truth — strictly more reliable.
#
# What it injects:
#   1. Branch + last 5 commits + uncommitted status (real progress signal)
#   2. Open PRs touching this branch (parallel-work detection)
#   3. Last claudemem note tagged "workflow-retro" (closes feedback loop)
#   4. Backward compat: legacy dev-progress.json if present
#
# Compatible with Opus 4.6/4.7. Obsolescence condition: when Claude Code's
# native session resume captures all of this without a hook.
#
# Security: variables passed via environment, never interpolated into code.
set -euo pipefail

CONTEXT=""

# 1. Git ground truth
if BRANCH=$(git branch --show-current 2>/dev/null) && [[ -n "$BRANCH" ]]; then
  RECENT=$(git log --oneline -5 2>/dev/null || echo "")
  STATUS=$(git status --short 2>/dev/null | head -10 || echo "")
  CONTEXT="Branch: ${BRANCH}"
  [[ -n "$RECENT" ]] && CONTEXT="${CONTEXT}\nRecent commits:\n${RECENT}"
  if [[ -n "$STATUS" ]]; then
    CONTEXT="${CONTEXT}\nUncommitted:\n${STATUS}"
  else
    CONTEXT="${CONTEXT}\nWorking tree: clean"
  fi
fi

# 2. Open PRs (gh CLI optional)
if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  PRS=$(gh pr list --state open --limit 3 --json number,title,headRefName \
        --template '{{range .}}#{{.number}} [{{.headRefName}}] {{.title}}{{"\n"}}{{end}}' \
        2>/dev/null || echo "")
  if [[ -n "$PRS" ]]; then
    CONTEXT="${CONTEXT}\nOpen PRs:\n${PRS}"
  fi
fi

# 3. Last workflow-retro note from claudemem (feedback loop)
if command -v claudemem &>/dev/null; then
  RETRO=$(claudemem search "workflow-retro" --compact --format json --limit 1 2>/dev/null \
          | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data and isinstance(data, list) and len(data) > 0:
        print(data[0].get('title', ''))
except Exception:
    pass
" 2>/dev/null || echo "")
  if [[ -n "$RETRO" ]]; then
    CONTEXT="${CONTEXT}\nLast workflow lesson: ${RETRO} (search claudemem for full content)"
  fi
fi

# 4. Backward compat: legacy dev-progress.json (if SKILL ever wires it up)
BRANCH_SAFE=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_FILE=".claude/dev-progress/${BRANCH_SAFE}.json"
[[ ! -f "$PROGRESS_FILE" ]] && PROGRESS_FILE=".claude/dev-progress.json"
if [[ -f "$PROGRESS_FILE" ]]; then
  # SECURITY: pass file path via env, NOT string interpolation
  LEGACY=$(PROGRESS_FILE_PATH="$PROGRESS_FILE" python3 - <<'PY' 2>/dev/null || true
import json, datetime, os, sys
try:
    path = os.environ.get('PROGRESS_FILE_PATH', '')
    if not path:
        sys.exit(0)
    with open(path) as f:
        d = json.load(f)
    ts = datetime.datetime.fromisoformat(d.get('updated_at', '2000-01-01T00:00:00+00:00'))
    age_hours = (datetime.datetime.now(datetime.timezone.utc) - ts).total_seconds() / 3600
    if age_hours > 24:
        sys.exit(0)
    subtasks = d.get('subtasks', [])
    done = sum(1 for s in subtasks if s.get('status') == 'done')
    total = len(subtasks)
    print(f"Resuming /dev: task={d.get('task','?')!r} phase={d.get('phase','?')} progress={done}/{total}")
except Exception:
    sys.exit(0)
PY
  )
  if [[ -n "$LEGACY" ]]; then
    CONTEXT="${CONTEXT}\n${LEGACY}"
  fi
fi

# Output via JSON additionalContext (must include hookEventName per Claude Code schema)
if [[ -n "$CONTEXT" ]]; then
  CONTEXT_BODY="$CONTEXT" python3 - <<'PY' 2>/dev/null || true
import json, os
ctx = os.environ.get('CONTEXT_BODY', '').replace('\\n', '\n').strip()
if ctx:
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': ctx,
    }}))
PY
fi
exit 0
