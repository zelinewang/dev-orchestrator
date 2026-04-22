#!/usr/bin/env bash
# PreToolUse:Bash hook — gate git commits behind verification.
# Part of /dev v4 workflow system. Compatible with Opus 4.6/4.7.
# This is the "script floor" — deterministic enforcement, not AI intent.
#
# Two-tier enforcement:
#   - verify-dev.sh failure → exit 2 (HARD BLOCK, cannot be auto-accepted)
#   - ruff lint issues → additionalContext warning (visible but non-blocking,
#     because staged files may have pre-existing lint issues not from this commit)
#
# Obsolescence condition: when CI catches 100% of issues post-push.
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Only intercept git commit (not amend, not merge)
if [[ "$COMMAND" != *"git commit"* ]]; then
  exit 0
fi
if [[ "$COMMAND" == *"--amend"* || "$COMMAND" == *"merge"* ]]; then
  exit 0
fi

# Tier 1: verify-dev.sh → HARD BLOCK (exit 2)
VERIFY_SCRIPT="${HOME}/.claude/scripts/verify-dev.sh"
if [[ -x "$VERIFY_SCRIPT" ]]; then
  VERIFY_OUTPUT=$("$VERIFY_SCRIPT" 2>&1) || {
    echo "BLOCKED: verify-dev.sh failed. Fix issues before committing:" >&2
    echo "$VERIFY_OUTPUT" | head -20 >&2
    exit 2
  }
fi

# Tier 2: ruff lint on staged Python files → WARNING via additionalContext
# Uses additionalContext (not permissionDecision) because pre-existing lint
# issues in staged files should not block commits of unrelated changes.
STAGED_PY=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep '\.py$' || true)
if [[ -n "$STAGED_PY" ]] && command -v ruff &>/dev/null; then
  LINT_OUTPUT=$(echo "$STAGED_PY" | xargs ruff check --select=E,W,F --ignore=E501 2>&1) || {
    LINT_SUMMARY=$(echo "$LINT_OUTPUT" | tail -5)
    python3 -c "
import json, sys
reason = sys.stdin.read().strip()
out = {'hookSpecificOutput': {
    'additionalContext': 'WARNING: Ruff found lint issues in staged Python files. Consider fixing before commit:\n' + reason[:400]
}}
print(json.dumps(out))
" <<< "$LINT_SUMMARY"
    exit 0
  }
fi

exit 0
