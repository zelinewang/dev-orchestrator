#!/usr/bin/env bash
# Async session retrospective extractor.
#
# Invoked by dev-session-end.sh in detached background mode. Reads the last
# N turns of the Claude Code transcript and uses Bedrock Haiku to extract
# 1-2 specific lessons, then saves to claudemem with workflow-retro tag.
#
# Pattern proven by ECC continuous-learning-v2: shell-side LLM call writes
# directly to disk-backed memory; no Claude turn involvement required.
# See coreSchemas.ts:916-932 — Stop hook cannot inject additionalContext,
# but it CAN read transcript_path and spawn shell processes.
#
# Required env vars from caller:
#   TRANSCRIPT_PATH — path to current session's JSONL transcript
#   BRANCH_SAFE     — sanitized branch name (slashes → dashes)
#   COMMITS_RECENT  — number of commits in cooldown window
#
# Optional env vars:
#   CLAUDE_DEV_AUTO_RETRO=0 → opt-out
#   CLAUDE_DEV_AUTO_RETRO_MODEL → override default model (haiku)
#
# Failure mode: silent (no stdout/stderr to user). All errors logged to
# /tmp/dev-retro-extract.log for debugging.
set -euo pipefail

LOG_FILE="/tmp/dev-retro-extract.log"
exec >>"$LOG_FILE" 2>&1
echo "[$(date -Iseconds)] dev-retro-extract starting (branch=${BRANCH_SAFE:-?}, commits=${COMMITS_RECENT:-?})"

# Opt-out gate
if [[ "${CLAUDE_DEV_AUTO_RETRO:-1}" == "0" ]]; then
  echo "  opt-out via CLAUDE_DEV_AUTO_RETRO=0"
  exit 0
fi

# Validate inputs
TRANSCRIPT_PATH="${TRANSCRIPT_PATH:-}"
if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "  no transcript at: $TRANSCRIPT_PATH"
  exit 0
fi

# Verify Bedrock claude is available; fail silent otherwise
if ! command -v claude >/dev/null 2>&1; then
  echo "  claude CLI not found; skipping"
  exit 0
fi

MODEL="${CLAUDE_DEV_AUTO_RETRO_MODEL:-haiku}"

# Extract last N turns of transcript content (avoid sending full 7000+ line transcripts)
# Tail by lines, then keep only meaningful turn content via Python
TRANSCRIPT_EXCERPT=$(TRANSCRIPT_PATH="$TRANSCRIPT_PATH" python3 - <<'PY' 2>/dev/null || true
import json
import os
import sys

path = os.environ['TRANSCRIPT_PATH']
keep = []
# Read last ~100KB; transcripts can be huge
size = os.path.getsize(path)
with open(path, 'rb') as f:
    if size > 100_000:
        f.seek(-100_000, 2)
        f.readline()  # skip partial line
    for line in f:
        try:
            d = json.loads(line)
        except Exception:
            continue
        ttype = d.get('type', '')
        if ttype == 'user':
            content = (d.get('message', {}) or {}).get('content', '')
            if isinstance(content, list):
                content = ''.join(c.get('text', '') for c in content if isinstance(c, dict))
            if content and isinstance(content, str):
                keep.append(f"USER: {content[:500]}")
        elif ttype == 'assistant':
            content = (d.get('message', {}) or {}).get('content', [])
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        keep.append(f"ASSISTANT: {(c.get('text') or '')[:500]}")
                    elif isinstance(c, dict) and c.get('type') == 'tool_use':
                        keep.append(f"TOOL_USE: {c.get('name','?')}")
# Keep last 40 entries to stay under ~10K tokens
keep = keep[-40:]
print('\n'.join(keep))
PY
)

if [[ -z "$TRANSCRIPT_EXCERPT" ]]; then
  echo "  empty transcript excerpt"
  exit 0
fi

# Prompt the Bedrock model to extract specific lessons
read -r -d '' EXTRACTOR_PROMPT <<'EOF' || true
Read this Claude Code session excerpt. Extract 1-2 SPECIFIC lessons that would help a future session avoid mistakes or repeat successes.

Strict criteria:
- Each lesson must be NON-OBVIOUS (not generic programming wisdom).
- Must be specific to this session's context (cite a tool/file/decision).
- Format each lesson as:
  TITLE: <one-line rule, max 80 chars>
  WHY: <reason from this session, max 200 chars>
  WHEN: <condition that triggers this rule applying, max 200 chars>
- Separate multiple lessons with "---".
- If nothing notable was learned (routine session, no surprises), output exactly: NOTHING

Session excerpt follows.
EOF

LESSONS=$(printf '%s\n\n%s\n' "$EXTRACTOR_PROMPT" "$TRANSCRIPT_EXCERPT" | \
    CLAUDE_CODE_USE_BEDROCK=1 \
    timeout 120 claude -p --model "$MODEL" --output-format text 2>/dev/null || true)

# Skip if nothing extracted or 'NOTHING' marker
if [[ -z "$LESSONS" || "${LESSONS:0:7}" == "NOTHING" || "$LESSONS" == *"NOTHING"* ]] && [[ ${#LESSONS} -lt 50 ]]; then
  echo "  no notable lessons (LLM said NOTHING or empty)"
  exit 0
fi

# Validate output has expected structure
if ! echo "$LESSONS" | grep -qE '(TITLE|^[A-Z]):'; then
  echo "  malformed output, skipping save: ${LESSONS:0:200}"
  exit 0
fi

# Save to claudemem
NOTE_TITLE="Auto-retro: ${BRANCH_SAFE} (${COMMITS_RECENT} commits, $(date +%Y-%m-%d))"
NOTE_BODY=$(printf 'Auto-extracted session retrospective.\n\nBranch: %s\nCommits in window: %s\nDate: %s\n\n---\n\n%s\n' \
    "${BRANCH_SAFE}" "${COMMITS_RECENT}" "$(date -Iseconds)" "$LESSONS")

# Use stdin to avoid command-line length / quoting issues
TMP_NOTE=$(mktemp)
printf '%s' "$NOTE_BODY" > "$TMP_NOTE"
if claudemem note add architecture \
    --title "$NOTE_TITLE" \
    --tags "workflow-retro,auto-retro,v5-feedback" < "$TMP_NOTE" 2>&1 | head -3; then
  echo "  saved retro: $NOTE_TITLE"
else
  echo "  claudemem save failed"
fi
rm -f "$TMP_NOTE" 2>/dev/null || true

exit 0
