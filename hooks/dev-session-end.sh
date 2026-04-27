#!/usr/bin/env bash
# Stop hook (v5.2.1 — codex-review fix #2): cooldown reads success file.
#
# v5.2.1 changes vs v5.2.0:
#   #2 Cooldown gate now reads `.last-retro-success-<branch>` (written ONLY
#      after extractor's successful claudemem save), not pre-emptive timestamp.
#      Failed extractions no longer consume the 30min slot.
#   #7 BRANCH_SAFE uses strict alnum+dash sanitize (caller-side defense).
#
# Schema reality (verified from Claude Code coreSchemas.ts:916-932):
#   Stop hook does NOT accept hookSpecificOutput. Only base fields:
#   continue / suppressOutput / stopReason / decision / reason / systemMessage.
#   None of these inject context into Claude.
#
# Goal: close the feedback loop (session N's lessons reach session N+1)
# WITHOUT requiring manual /wrapup invocation.
#
# Approach (proven by ECC continuous-learning-v2 + session-end.js):
#   - Stop hook receives transcript_path in stdin.
#   - We read transcript_path + check signals (commits, cooldown).
#   - If signals met, spawn DETACHED async retro extractor (nohup + &).
#   - Extractor uses Bedrock Haiku to write workflow-retro note to claudemem.
#   - Extractor writes success-timestamp ONLY on save success.
#   - session-start hook reads `.last-retro-id-<branch>` for direct recency.
#   - This hook itself outputs NOTHING (schema-compliant Stop).
set -euo pipefail

INPUT=$(cat)

# Sync, lightweight: extract transcript_path
TRANSCRIPT_PATH=$(INPUT_BODY="$INPUT" python3 - <<'PY' 2>/dev/null || true
import json, os
try:
    d = json.loads(os.environ.get('INPUT_BODY', ''))
    print(d.get('transcript_path', ''))
except Exception:
    pass
PY
)

# Exit silently if no transcript path
[[ -z "$TRANSCRIPT_PATH" ]] && exit 0
[[ ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# Fix #7: strict branch-name sanitization (alnum + dash only)
BRANCH_RAW=$(git branch --show-current 2>/dev/null || echo "")
BRANCH_SAFE=$(printf '%s' "$BRANCH_RAW" | tr -c 'a-zA-Z0-9-' '-' | tr -s '-' | sed 's/^-//;s/-$//')
[[ -z "$BRANCH_SAFE" ]] && BRANCH_SAFE="default"

PROGRESS_DIR=".claude/dev-progress"

# Fix #2: cooldown gate reads `.last-retro-success-<branch>` (written by
# extractor on save success), not pre-emptive timestamp. A failed extraction
# leaves this file unchanged → next Stop tries again.
LAST_SUCCESS_FILE="${PROGRESS_DIR}/.last-retro-success-${BRANCH_SAFE}"
COOLDOWN_SECONDS="${CLAUDE_DEV_AUTO_RETRO_COOLDOWN:-1800}"  # 30 min default
NOW=$(date +%s)
LAST_SUCCESS_AT=$(cat "$LAST_SUCCESS_FILE" 2>/dev/null || echo 0)

# Real-work signal: at least 1 commit in cooldown window
COMMITS_RECENT=0
if git rev-parse --git-dir &>/dev/null; then
  COMMITS_RECENT=$(git log --since="${COOLDOWN_SECONDS} seconds ago" --oneline 2>/dev/null | wc -l | tr -d ' ' || echo 0)
fi

# Spawn async extractor if: cooldown elapsed AND commits exist
if [[ $((NOW - LAST_SUCCESS_AT)) -ge "$COOLDOWN_SECONDS" ]] && [[ "$COMMITS_RECENT" -ge 1 ]]; then
  # Detached async via nohup + & + disown (survives Claude Code shutdown)
  TRANSCRIPT_PATH="$TRANSCRIPT_PATH" \
  BRANCH_SAFE="$BRANCH_SAFE" \
  COMMITS_RECENT="$COMMITS_RECENT" \
  CLAUDE_DEV_AUTO_RETRO_PROGRESS_DIR="$PROGRESS_DIR" \
  nohup bash "$HOME/.claude/scripts/dev-retro-extract.sh" </dev/null >/dev/null 2>&1 &
  disown
fi

# Backward compat: still update progress.json timestamp (cross-session resume signal)
PROGRESS_FILE="${PROGRESS_DIR}/${BRANCH_SAFE}.json"
[[ ! -f "$PROGRESS_FILE" ]] && PROGRESS_FILE=".claude/dev-progress.json"
if [[ -f "$PROGRESS_FILE" ]]; then
  PROGRESS_FILE_PATH="$PROGRESS_FILE" python3 - <<'PY' 2>/dev/null || true
import json, datetime, os
path = os.environ.get('PROGRESS_FILE_PATH', '')
if path:
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

# CRITICAL: silent stdout — Stop schema rejects hookSpecificOutput
exit 0
