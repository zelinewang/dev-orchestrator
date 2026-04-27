#!/usr/bin/env bash
# Stop hook (v5): close the feedback loop by nudging learning extraction.
#
# v4 version: only updated timestamp in dev-progress.json (which nothing reads)
# v5 version: if the session did real work (commits made), inject a final
# additionalContext nudge to save key learnings to claudemem with the
# "workflow-retro" tag — which the next session's session-start hook reads.
#
# This is the missing feedback loop: session N's lessons reach session N+1
# without requiring user intervention or /wrapup invocation.
#
# Backward compat: still updates legacy dev-progress.json timestamp if present.
#
# Security: env-var variable passing, no string interpolation.
set -euo pipefail

# Count commits made in this session window (8h proxy)
COMMITS_RECENT=0
if git rev-parse --git-dir &>/dev/null; then
  COMMITS_RECENT=$(git log --since="8 hours ago" --oneline 2>/dev/null | wc -l | tr -d ' ' || echo 0)
fi

# Inject learning nudge if real work happened
if [[ "$COMMITS_RECENT" -gt 0 ]]; then
  COMMITS_N="$COMMITS_RECENT" python3 - <<'PY' 2>/dev/null || true
import json, os
n = os.environ.get('COMMITS_N', '0')
msg = (
    f"Session ending with {n} commits. Before finishing: save key learnings to "
    f"claudemem with tag 'workflow-retro' so next session's start hook can surface them. "
    f"Focus on non-obvious findings: bug root causes, architecture decisions, API quirks, "
    f"config gotchas. Skip generic programming knowledge."
)
print(json.dumps({'hookSpecificOutput': {'additionalContext': msg}}))
PY
fi

# Backward compat: update timestamp on legacy progress file (if SKILL still uses it)
BRANCH_SAFE=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_FILE=".claude/dev-progress/${BRANCH_SAFE}.json"
[[ ! -f "$PROGRESS_FILE" ]] && PROGRESS_FILE=".claude/dev-progress.json"
if [[ -f "$PROGRESS_FILE" ]]; then
  PROGRESS_FILE_PATH="$PROGRESS_FILE" python3 - <<'PY' 2>/dev/null || true
import json, datetime, os
path = os.environ.get('PROGRESS_FILE_PATH', '')
if not path:
    raise SystemExit(0)
try:
    with open(path, 'r+') as f:
        d = json.load(f)
        d['updated_at'] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        f.seek(0)
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.truncate()
except Exception:
    pass
PY
fi

exit 0
