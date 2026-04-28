#!/usr/bin/env bash
# SessionStart hook (v5.3.0 — adds concurrent-PR feature deletion detector).
#
# v5.3.0 changes vs v5.2.1:
#   Add F_CONCURRENT — surfaces files I recently touched that OTHERS have
#   committed to since. Prevents "concurrent PR deletes my features without
#   saying so" surprise on session resume (real incident 2026-04-27 PR #2544
#   case; see ~/.claude/projects/-home-zane-VisPie-backend/memory/
#   feedback_concurrent_pr_feature_deletion.md).
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
#   5. NEW v5.3.0: Concurrent PR activity warnings on my recently-touched files
#
# Compatible with Opus 4.6/4.7. Obsolescence condition: when Claude Code's
# native session resume captures all of this without a hook.
#
# Security: variables passed via environment, never interpolated into code.
# Performance: F_CONCURRENT bounded by `timeout 3` on fetch + max 20 files
# scanned + early-break at 5 warnings; total added latency ≤ ~5s worst case.
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

# ----------------------------------------------------------------------------
# v5.3.0: Concurrent PR activity detector
# Surfaces files I recently touched that OTHERS have committed to since.
# Prevents "Ashley PR #2544 deleted my MAX_ANALYZE_ATTEMPTS without saying so
# in PR description" surprise (real 2026-04-27 incident — see claudemem note
# feedback_concurrent_pr_feature_deletion).
#
# All steps are best-effort with || true fallback; never aborts session start.
# Hard timeout on git fetch prevents network-stalls from blocking startup.
# ----------------------------------------------------------------------------
F_CONCURRENT=""
# Use git user.name as identity filter — robust to multiple email aliases.
# Real failure mode: zelinwang10@gmail.com vs zelinwang@andrew.cmu.edu both
# show as "Zane Wang" but only one matches `--author=email`. Name-based
# filter catches both. Falls back to email if name not configured.
MY_NAME=$(git config user.name 2>/dev/null || echo "")
MY_FILTER="$MY_NAME"
[[ -z "$MY_FILTER" ]] && MY_FILTER=$(git config user.email 2>/dev/null || echo "")

if [[ -n "$MY_FILTER" ]]; then
  # Best-effort: refresh origin's default branch so "since 3 days ago by others"
  # is current. v5.3.1 fix: detect default branch dynamically (master vs main).
  # Hardcoded "origin master" silently fails on `main`-default repos (fetch
  # returns nonzero, || true swallows it, local ref stays stale → false negatives).
  # 3-second hard cap; if network is slow/down, just skip refresh (we still
  # check local refs, which is better than nothing).
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
                   | sed 's|^refs/remotes/origin/||' || echo "master")
  [[ -z "$DEFAULT_BRANCH" ]] && DEFAULT_BRANCH="master"
  timeout 3 git fetch --quiet origin "$DEFAULT_BRANCH" 2>/dev/null || true

  # Files I committed to in last 5 days (cap 20 for performance bound).
  # awk 'NF' filters empty lines from --pretty=format: between commits.
  # --author=PATTERN matches against author name AND email; name catches
  # commits made under ALL my email aliases.
  MY_RECENT_FILES=$(git log --since='5 days ago' --author="$MY_FILTER" \
    --name-only --pretty=format: 2>/dev/null \
    | awk 'NF' | sort -u | head -20 || echo "")

  if [[ -n "$MY_RECENT_FILES" ]]; then
    CONCURRENT_LINES=""
    COUNT=0
    # while-read handles filenames with spaces correctly (vs `for f in $list`).
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      [[ ! -f "$f" ]] && continue   # skip deleted files (renamed/moved away)
      # Filter "OTHERS" via post-process awk-field-compare, NOT via `--not --author=`.
      # WARNING: `git log --not --author=PATTERN` does NOT invert the author
      # filter — `--not` only affects revision selection (^commit semantics).
      # Confirmed empirically 2026-04-28: --not --author="Zane Wang" still
      # returned Zane Wang commits. The reliable way is field-compare on output:
      #   1. Format each commit as `hash|author_name|subject` (pipe-delimited)
      #   2. awk -F'|' '$2 != me' to drop my own commits (literal compare,
      #      v5.3.1 fix: was grep regex which would mis-match names with
      #      regex meta chars like `.` `*` `[`)
      #   3. Reformat with awk for display
      # This is robust to git internals + handles all email aliases under one name.
      OTHERS=$(git log --since='3 days ago' \
        --pretty=format:'%h|%an|%s' -- "$f" 2>/dev/null \
        | awk -F'|' -v me="$MY_FILTER" '$2 != me' \
        | head -2 \
        | awk -F'|' '{printf "    %s %s (%s)\n", $1, $3, $2}' \
        || echo "")
      if [[ -n "$OTHERS" ]]; then
        CONCURRENT_LINES+="  ${f}:"$'\n'"${OTHERS}"$'\n'
        COUNT=$((COUNT + 1))
        # Cap at 5 files-with-warnings to avoid overwhelming session-start context.
        [[ $COUNT -ge 5 ]] && break
      fi
    done <<< "$MY_RECENT_FILES"
    F_CONCURRENT="$CONCURRENT_LINES"
  fi
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
F_CONCURRENT="$F_CONCURRENT" \
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

# v5.3.0: surface concurrent PR activity on my recently-touched files.
# Calls out the "PR description didn't disclose deletions" risk explicitly so
# the agent will run `git show <sha> -- <file> | grep '^-'` before continuing.
concurrent = get('F_CONCURRENT')
if concurrent:
    parts.append(
        "WARNING: Others recently modified files you authored. Verify nothing was deleted "
        "(check `git show <sha> -- <file> | grep '^-'` before continuing your work):\n"
        + concurrent
    )

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
