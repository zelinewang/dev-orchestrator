#!/usr/bin/env bash
# Stop hook (v5.1 fix): silent timestamp update only.
#
# Schema constraint: Stop event does NOT accept hookSpecificOutput
# (only PreToolUse / UserPromptSubmit / PostToolUse / PostToolBatch do).
# Stop accepts: continue / suppressOutput / stopReason / decision / reason /
# systemMessage. None of these inject context into Claude.
#
# Stop also fires on EVERY turn end (not just session close), so a per-Stop
# nudge would be spam regardless of schema.
#
# Right design: the feedback loop lives in session-start (which DOES accept
# additionalContext via hookSpecificOutput). It surfaces last workflow-retro
# claudemem note. Saving the note is /wrapup's job (or manual `claudemem
# note add ... --tags workflow-retro`).
#
# Therefore this hook is now SILENT except for the legacy progress.json
# timestamp bookkeeping — which had value (cross-session resume) and is the
# only thing left to do.
#
# Security: env-var variable passing, no string interpolation.
set -euo pipefail

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
