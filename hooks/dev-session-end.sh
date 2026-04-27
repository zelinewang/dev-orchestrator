#!/usr/bin/env bash
# Stop hook (v5.2 root fix): silent stdout + async retro extraction.
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
#   - session-start hook surfaces the latest retro on next session start.
#   - This hook itself outputs NOTHING (schema-compliant Stop).
#
# Why this design:
#   - No schema risk: silent stdout = always valid for Stop event.
#   - Goal achieved: feedback loop closes via shell-side LLM, not Claude turn.
#   - Non-blocking: async detached, Stop turn flow preserved.
#   - Cost-controlled: 30-min cooldown + commits>0 gate; ~$0.05 per actual fire.
#   - Opt-out: CLAUDE_DEV_AUTO_RETRO=0 in env disables.
#
# Backward compat: still updates legacy dev-progress.json timestamp if present.
set -euo pipefail

INPUT=$(cat)

# Sync, lightweight: extract transcript_path, check cooldown, decide if spawn worthwhile
TRANSCRIPT_PATH=$(INPUT_BODY="$INPUT" python3 - <<'PY' 2>/dev/null || true
import json, os, sys
try:
    d = json.loads(os.environ.get('INPUT_BODY', ''))
    print(d.get('transcript_path', ''))
except Exception:
    pass
PY
)

# Exit silently if no transcript path (older Claude Code versions, or other hook event reused this hook)
[[ -z "$TRANSCRIPT_PATH" ]] && exit 0
[[ ! -f "$TRANSCRIPT_PATH" ]] && exit 0

# Branch-scoped cooldown to prevent retro spam (Stop fires per-turn end)
BRANCH_SAFE=$(git branch --show-current 2>/dev/null | tr '/' '-' || echo "default")
PROGRESS_DIR=".claude/dev-progress"
LAST_RETRO_FILE="${PROGRESS_DIR}/.last-retro-${BRANCH_SAFE}"
COOLDOWN_SECONDS="${CLAUDE_DEV_AUTO_RETRO_COOLDOWN:-1800}"  # 30 min default
NOW=$(date +%s)
LAST_RETRO_AT=$(cat "$LAST_RETRO_FILE" 2>/dev/null || echo 0)

# Real-work signal: at least 1 commit in cooldown window
COMMITS_RECENT=0
if git rev-parse --git-dir &>/dev/null; then
  COMMITS_RECENT=$(git log --since="${COOLDOWN_SECONDS} seconds ago" --oneline 2>/dev/null | wc -l | tr -d ' ' || echo 0)
fi

# Spawn async extractor if: cooldown elapsed AND commits exist
if [[ $((NOW - LAST_RETRO_AT)) -ge "$COOLDOWN_SECONDS" ]] && [[ "$COMMITS_RECENT" -ge 1 ]]; then
  mkdir -p "$PROGRESS_DIR"
  echo "$NOW" > "$LAST_RETRO_FILE"

  # Detached async via setsid + nohup (survives Claude Code shutdown)
  TRANSCRIPT_PATH="$TRANSCRIPT_PATH" \
  BRANCH_SAFE="$BRANCH_SAFE" \
  COMMITS_RECENT="$COMMITS_RECENT" \
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
