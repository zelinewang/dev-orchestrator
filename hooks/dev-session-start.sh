#!/usr/bin/env bash
# SessionStart hook (v5.2.1 — codex-review fix #3, #6, #7).
#
# v5.2.1 changes vs v5.2.0:
#   #3 Read latest workflow-retro note via stored note ID
#      (`.last-retro-id-<branch>`) instead of `claudemem search` which is
#      relevance-ranked, not recency-ranked. Fallback to search if no ID file.
#   #6 Build CONTEXT entirely in Python from per-field env vars; eliminate
#      bash `\n` literal interpolation that mangled real newlines from
#      command substitution.
#   #7 Strict branch-name sanitization (alnum + dash only).
#
# What it injects:
#   1. Branch + last 5 commits + uncommitted status (real progress signal)
#   2. Open PRs touching this branch (parallel-work detection)
#   3. Last claudemem note tagged "workflow-retro" by direct ID read (recency
#      guaranteed) with relevance-search fallback
#   4. Backward compat: legacy dev-progress.json if present
#
# Compatible with Opus 4.6/4.7. Obsolescence condition: when Claude Code's
# native session resume captures all of this without a hook.
#
# Security: variables passed via environment, never interpolated into code.
set -euo pipefail

# ----------------------------------------------------------------------------
# Gather raw fields (each as separate env var to avoid \n interpolation pitfalls)
# ----------------------------------------------------------------------------
F_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
F_RECENT=$(git log --oneline -5 2>/dev/null || echo "")
F_STATUS=$(git status --short 2>/dev/null | head -10 || echo "")

F_PRS=""
if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
  F_PRS=$(gh pr list --state open --limit 3 --json number,title,headRefName \
        --template '{{range .}}#{{.number}} [{{.headRefName}}] {{.title}}{{"\n"}}{{end}}' \
        2>/dev/null || echo "")
fi

# Fix #7: strict branch sanitization
BRANCH_SAFE=$(printf '%s' "$F_BRANCH" | tr -c 'a-zA-Z0-9-' '-' | tr -s '-' | sed 's/^-//;s/-$//')
[[ -z "$BRANCH_SAFE" ]] && BRANCH_SAFE="default"

# ----------------------------------------------------------------------------
# Fix #3: prefer reading latest retro by stored note ID (recency guaranteed)
# rather than relevance-ranked claudemem search.
# Fallback chain:
#   1. .claude/dev-progress/.last-retro-id-<branch> → claudemem note get <id>
#   2. claudemem search "workflow-retro" --limit 1 (legacy, relevance-ranked)
#   3. empty
# ----------------------------------------------------------------------------
F_RETRO=""
ID_FILE=".claude/dev-progress/.last-retro-id-${BRANCH_SAFE}"
if [[ -f "$ID_FILE" ]] && command -v claudemem &>/dev/null; then
  STORED_ID=$(head -1 "$ID_FILE" 2>/dev/null | tr -dc 'a-zA-Z0-9_-')
  if [[ -n "$STORED_ID" && ${#STORED_ID} -ge 6 ]]; then
    # Try to fetch by exact ID — recency guaranteed
    F_RETRO_BODY=$(claudemem note get "$STORED_ID" 2>/dev/null | head -3 || echo "")
    if [[ -n "$F_RETRO_BODY" ]]; then
      # Extract title line (claudemem note get prints "Title: <title>")
      F_RETRO=$(printf '%s' "$F_RETRO_BODY" | grep -i '^Title:' | head -1 | sed 's/^Title:[[:space:]]*//' || echo "")
    fi
  fi
fi
# Fallback: legacy search if no stored ID or fetch failed
if [[ -z "$F_RETRO" ]] && command -v claudemem &>/dev/null; then
  F_RETRO=$(claudemem search "workflow-retro" --compact --format json --limit 1 2>/dev/null \
    | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if data and isinstance(data, list) and len(data) > 0:
        print(data[0].get('title', ''))
except Exception:
    pass
" 2>/dev/null || echo "")
fi

# Backward compat: legacy dev-progress.json
PROGRESS_FILE=".claude/dev-progress/${BRANCH_SAFE}.json"
[[ ! -f "$PROGRESS_FILE" ]] && PROGRESS_FILE=".claude/dev-progress.json"
F_LEGACY=""
if [[ -f "$PROGRESS_FILE" ]]; then
  F_LEGACY=$(PROGRESS_FILE_PATH="$PROGRESS_FILE" python3 - <<'PY' 2>/dev/null || true
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
fi

# ----------------------------------------------------------------------------
# Fix #6: build the entire CONTEXT in Python from typed env vars.
# No bash \n interpolation; real newlines stay as real newlines.
# ----------------------------------------------------------------------------
F_BRANCH="$F_BRANCH" \
F_RECENT="$F_RECENT" \
F_STATUS="$F_STATUS" \
F_PRS="$F_PRS" \
F_RETRO="$F_RETRO" \
F_LEGACY="$F_LEGACY" \
python3 - <<'PY' 2>/dev/null || true
import json
import os

def get(k):
    return os.environ.get(k, '').strip()

parts = []
branch = get('F_BRANCH')
if branch:
    parts.append(f"Branch: {branch}")

recent = get('F_RECENT')
if recent:
    parts.append("Recent commits:\n" + recent)

status = get('F_STATUS')
parts.append("Uncommitted:\n" + status if status else "Working tree: clean")

prs = get('F_PRS')
if prs:
    parts.append("Open PRs:\n" + prs)

retro = get('F_RETRO')
if retro:
    parts.append(f"Last workflow lesson: {retro} (search claudemem for full content)")

legacy = get('F_LEGACY')
if legacy:
    parts.append(legacy)

ctx = '\n'.join(parts).strip()
if ctx:
    # Schema: SessionStart hook accepts hookSpecificOutput.additionalContext
    print(json.dumps({'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': ctx,
    }}))
PY

exit 0
