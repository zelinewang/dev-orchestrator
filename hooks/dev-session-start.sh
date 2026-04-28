#!/usr/bin/env bash
# SessionStart hook (v5.3.3 — codex-review hardening: 1 HIGH + 4 MEDIUM fixes).
#
# v5.3.3 changes vs v5.3.2 (from codex-review 2026-04-28):
#   HIGH: Strip `|` from MY_FILTER (git config user.name) — pipe in name
#         corrupted awk -F'|' parsing → all commits leaked as OTHERS.
#         Also limit to 200 chars and strip control chars for awk -v safety.
#   MED1: Show "+N more" overflow indicator when concurrent commits per file
#         exceed display cap of 2 (was silent truncation, misleading).
#   MED2: Align my-files window with others-commits window via single
#         CLAUDE_DEV_CONCURRENT_WINDOW_DAYS env var (default 5d for both).
#         Was 5d/3d asymmetric → false negatives on 3-5d old work.
#   MED3: Sanitize DEFAULT_BRANCH against git-flag injection. Reject leading
#         dash to block `--exec=evil` style attacks via crafted symbolic-ref.
#   MED4: Field separator `\x1f` (ASCII Unit Separator, designed exactly for
#         this) instead of `|`. Pipe could appear in commit subjects causing
#         field misalignment. NUL was tried first but bash strips NUL bytes
#         in command substitution.
#
# v5.3.2 changes vs v5.3.1:
#   Move CONCURRENT WARNING to top of context (was buried after PRs).
#   Action-required signals belong first — agent processes context top-down
#   and a buried WARNING risks being skimmed past, defeating the detector.
#   Wrapped in `=== ⚠ ===` separator for visual distinction.
#
# v5.3.1 changes vs v5.3.0:
#   #1 Default branch detected dynamically (master vs main) — was hardcoded
#      `origin master`, silently failed on main-default repos.
#   #2 OTHERS filter via awk field-compare — was grep regex, broke on names
#      with regex meta chars (. * [).
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
# v5.3.3: Concurrent PR activity detector (codex-review hardening)
# Surfaces files I recently touched that OTHERS have committed to since.
# Prevents "Ashley PR #2544 deleted my MAX_ANALYZE_ATTEMPTS without saying so
# in PR description" surprise (real 2026-04-27 incident — see claudemem note
# feedback_concurrent_pr_feature_deletion).
#
# v5.3.3 fixes vs v5.3.2 (5 findings from codex-review 2026-04-28):
#   HIGH: pipe-char in MY_FILTER → strip `|` to prevent awk -F'|' field
#         misalignment that would cause every commit to leak as OTHERS
#   MED1: head -2 silent truncation → show "+N more" overflow indicator
#   MED2: 5d/3d window asymmetry → align both windows via single var
#   MED3: git fetch flag injection via DEFAULT_BRANCH → strict sanitize +
#         reject leading dash to block `--exec=evil` style attacks
#   MED4: commit-subject pipe corruption → use \x00 (NUL) field separator
#         which can never appear in git output
#
# All steps are best-effort with || true fallback; never aborts session start.
# Hard timeout on git fetch prevents network-stalls from blocking startup.
# ----------------------------------------------------------------------------
F_CONCURRENT=""
# Use git user.name as identity filter — robust to multiple email aliases.
# Real failure mode: zelinwang10@gmail.com vs zelinwang@andrew.cmu.edu both
# show as "Zane Wang" but only one matches `--author=email`. Name-based
# filter catches both. Falls back to email if name not configured.
#
# v5.3.3 HIGH fix: strip `|` from name. Names like "Wang | Zane" would otherwise
# corrupt the awk -F'\x00' parsing if any consumer reverted to pipe-delimited.
# We also strip newlines/tabs/control chars that could break awk -v assignment.
MY_NAME_RAW=$(git config user.name 2>/dev/null || echo "")
MY_FILTER=$(printf '%s' "$MY_NAME_RAW" | tr -d '|\n\t\r\0')
if [[ -z "$MY_FILTER" ]]; then
  MY_EMAIL_RAW=$(git config user.email 2>/dev/null || echo "")
  MY_FILTER=$(printf '%s' "$MY_EMAIL_RAW" | tr -d '|\n\t\r\0')
fi
# Cap to 200 chars (defense vs absurd configs from untrusted .git/config)
MY_FILTER="${MY_FILTER:0:200}"

# v5.3.3 MED2 fix: single window for both my-files AND others-commits queries.
# Previous v5.3.2: my-files=5d but others=3d → "I authored 4d ago + teammate
# deleted 3.5d ago" was missed. Aligning both to 5d removes the false-negative.
# Override via env: CLAUDE_DEV_CONCURRENT_WINDOW_DAYS=N
WINDOW_DAYS="${CLAUDE_DEV_CONCURRENT_WINDOW_DAYS:-5}"

if [[ -n "$MY_FILTER" ]]; then
  # Best-effort: refresh origin's default branch so concurrent activity is current.
  # v5.3.3 MED3 fix: sanitize DEFAULT_BRANCH against flag-injection. A malicious
  # symbolic-ref planted by a hostile remote could be `--exec=evil` and pass
  # through `git fetch origin "$DEFAULT_BRANCH"` as a flag (git interprets
  # leading `-` as flag even when quoted). tr keeps only safe chars, then
  # explicitly reject leading dash.
  # 3-second hard cap; if network is slow/down, just skip refresh (we still
  # check local refs, which is better than nothing).
  DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
                   | sed 's|^refs/remotes/origin/||' || echo "master")
  # Sanitize: alnum + ./_/- only (matches git ref naming rules); reject leading dash
  DEFAULT_BRANCH=$(printf '%s' "$DEFAULT_BRANCH" | tr -c 'a-zA-Z0-9._/-' '-')
  if [[ -z "$DEFAULT_BRANCH" || "${DEFAULT_BRANCH:0:1}" == "-" ]]; then
    DEFAULT_BRANCH="master"
  fi
  timeout 3 git fetch --quiet origin "$DEFAULT_BRANCH" 2>/dev/null || true

  # Files I committed to in last $WINDOW_DAYS days (cap 20 for performance bound).
  # awk 'NF' filters empty lines from --pretty=format: between commits.
  # --author=PATTERN matches against author name AND email; name catches
  # commits made under ALL my email aliases.
  MY_RECENT_FILES=$(git log --since="${WINDOW_DAYS} days ago" --author="$MY_FILTER" \
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
      # returned Zane Wang commits. The reliable way is field-compare on output.
      #
      # v5.3.3 MED4 fix: use \x1f (ASCII Unit Separator, designed for this!)
      # as field separator. Pipe `|` would appear in commit subjects
      # ("feat: A|B parser") corrupting `-F'|'` parsing → wrong author check.
      # \x00 (NUL) was tried first but bash command substitution strips NUL
      # bytes ("warning: command substitution: ignored null byte"). \x1f survives
      # bash variables AND won't appear in normal git commit data.
      #
      # Two-pass to support v5.3.3 MED1 fix (overflow indicator):
      # 1. Compute total OTHERS count (not capped)
      # 2. Display first 2, append "+N more" if more exist
      ALL_OTHERS=$(git log --since="${WINDOW_DAYS} days ago" \
        --pretty=$'format:%h\x1f%an\x1f%s' -- "$f" 2>/dev/null \
        | awk -F$'\x1f' -v me="$MY_FILTER" '$2 != me' \
        || echo "")
      # awk count: NF→non-empty lines; c+0→guarantees integer output (default 0)
      OTHER_COUNT=$(printf '%s' "$ALL_OTHERS" | awk 'NF{c++} END{print c+0}')
      OTHERS=$(printf '%s' "$ALL_OTHERS" | head -2 \
        | awk -F$'\x1f' '{printf "    %s %s (%s)\n", $1, $3, $2}' \
        || echo "")
      if [[ -n "$OTHERS" && "$OTHER_COUNT" -gt 2 ]]; then
        EXTRA=$((OTHER_COUNT - 2))
        OTHERS+="    ... (+${EXTRA} more concurrent commit(s) on this file)"$'\n'
      fi
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

# v5.3.2: surface concurrent PR activity FIRST for maximum visibility.
# Action-required signals belong at the top — agent processes context
# top-down and a buried WARNING risks being skimmed past, defeating the
# whole point of the detector. Wrapped in `===` separators to make the
# block visually distinct from the grounding info that follows.
# Note: `get()` strips trailing whitespace so we explicitly add `\n` before
# the closing separator (otherwise it glues onto the last warning line).
concurrent = get('F_CONCURRENT')
if concurrent:
    parts.append(
        "=== ⚠ CONCURRENT PR ACTIVITY ===\n"
        "Others recently modified files you authored. Verify nothing was deleted "
        "(check `git show <sha> -- <file> | grep '^-'` before continuing your work):\n"
        + concurrent + "\n"
        "================================"
    )

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
