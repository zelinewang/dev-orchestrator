#!/bin/bash
# /dev-orchestrator verification gate
# Codifies RULE 1 (double-verify), RULE 4 (regression paranoia),
# RULE 5 (CICD awareness), RULE 6 (closed-loop) into executable checks.
#
# Usage: bash ~/.claude/scripts/verify-dev.sh [project-root]
# Exit codes: 0 = verified/warning, 1 = blocked (test failures)

set -o pipefail

# Mode detection: --research, --cicd, or default (develop)
MODE="develop"
while [[ "$1" == --* ]]; do
  case "$1" in
    --research) MODE="research"; shift ;;
    --cicd) MODE="cicd"; shift ;;
    *) shift ;;
  esac
done

PROJECT_ROOT="${1:-.}"
cd "$PROJECT_ROOT" 2>/dev/null || { echo "Cannot cd to $PROJECT_ROOT"; exit 1; }

FAILURES=0
WARNINGS=0

echo "=== /dev Verification Gate (mode: $MODE) ==="
echo ""

# ─── RULE 1: DOUBLE-VERIFY (run full test suite, capture counts) ─────────

echo "[RULE 1] Full test suite..."

# Auto-detect test command
TEST_CMD=""
if [ -f "Makefile" ] && grep -q "^test-all:" Makefile 2>/dev/null; then
  TEST_CMD="make test-all"
elif [ -f "Makefile" ] && grep -q "^test:" Makefile 2>/dev/null; then
  TEST_CMD="make test"
elif [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
  TEST_CMD="npm test"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "pytest.ini" ]; then
  TEST_CMD="python -m pytest -q"
elif [ -f "go.mod" ]; then
  TEST_CMD="go test ./... -count=1"
elif [ -f "Cargo.toml" ]; then
  TEST_CMD="cargo test"
fi

if [ -n "$TEST_CMD" ]; then
  echo "  Running: $TEST_CMD"
  TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1)
  TEST_EXIT=$?
  if [ $TEST_EXIT -eq 0 ]; then
    # Extract test counts from output (last few lines usually have summary)
    SUMMARY=$(echo "$TEST_OUTPUT" | tail -5)
    echo "  ✓ Tests passed"
    echo "  $SUMMARY" | head -3 | sed 's/^/  /'
  else
    echo "  ✗ BLOCKED: Tests failed (exit code $TEST_EXIT)"
    echo "$TEST_OUTPUT" | tail -10 | sed 's/^/  /'
    FAILURES=$((FAILURES+1))
  fi
else
  echo "  ⚠ No test command detected (no Makefile/package.json/pyproject.toml/go.mod/Cargo.toml)"
  WARNINGS=$((WARNINGS+1))
fi

# ─── RULE 4: REGRESSION PARANOIA (new code has tests?) ───────────────────

echo ""
echo "[RULE 4] New code vs new tests..."

REMOTE_BRANCH=$(git rev-parse --abbrev-ref "@{upstream}" 2>/dev/null || echo "origin/master")

# Count new source files (excluding tests, configs, docs)
NEW_SRC=$(git diff --name-only "$REMOTE_BRANCH" 2>/dev/null \
  | grep -E '\.(go|py|ts|js|rs|java|rb)$' \
  | grep -vE '_test\.|test_|\.test\.|\.spec\.|/tests/' \
  | wc -l | tr -d ' ')

# Count new test files
NEW_TESTS=$(git diff --name-only "$REMOTE_BRANCH" 2>/dev/null \
  | grep -E '_test\.|test_|\.test\.|\.spec\.|/tests/' \
  | wc -l | tr -d ' ')

echo "  New source files: $NEW_SRC"
echo "  New test files:   $NEW_TESTS"

if [ "$NEW_SRC" -gt 0 ] && [ "$NEW_TESTS" -eq 0 ]; then
  echo "  ⚠ WARNING: $NEW_SRC new source files but 0 new test files"
  WARNINGS=$((WARNINGS+1))
elif [ "$NEW_SRC" -gt 0 ]; then
  echo "  ✓ Tests present for new code"
fi

# ─── RULE 6: CLOSED-LOOP (scope check) ──────────────────────────────────

echo ""
echo "[RULE 6] Scope check..."
CHANGED=$(git diff --stat "$REMOTE_BRANCH" 2>/dev/null | tail -1)
if [ -n "$CHANGED" ]; then
  echo "  $CHANGED"
else
  echo "  No changes vs $REMOTE_BRANCH"
fi

# ─── QUALITY: No debug leftovers ─────────────────────────────────────────

echo ""
echo "[QUALITY] Checking for debug leftovers..."
TODOS=$(git diff "$REMOTE_BRANCH" -- '*.go' '*.py' '*.ts' '*.js' '*.rs' 2>/dev/null \
  | grep -cE '^\+.*(TODO|FIXME|HACK|XXX)' || true)
if [ "$TODOS" -gt 0 ]; then
  echo "  ⚠ Found $TODOS TODO/FIXME/HACK markers in new code"
  WARNINGS=$((WARNINGS+1))
else
  echo "  ✓ No debug leftovers"
fi

# ─── RESEARCH MODE: Coverage verification ────────────────────────────────

if [[ "$MODE" == "research" ]]; then
  echo "[RESEARCH] Coverage check..."
  SEARCH_TERM="${2:-}"
  REPORT_PATH="${3:-}"
  if [ -n "$SEARCH_TERM" ]; then
    NOTES=$(claudemem search "$SEARCH_TERM" --compact --format json --limit 10 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
    if [ "$NOTES" -gt 0 ]; then
      echo "  ✓ $NOTES claudemem notes found for '$SEARCH_TERM'"
    else
      echo "  ⚠ No claudemem notes found for '$SEARCH_TERM'"
      WARNINGS=$((WARNINGS+1))
    fi
  fi
  if [ -n "$REPORT_PATH" ] && [ -f "$REPORT_PATH" ]; then
    LINES=$(wc -l < "$REPORT_PATH" | tr -d ' ')
    echo "  ✓ Report exists: $REPORT_PATH ($LINES lines)"
  elif [ -n "$REPORT_PATH" ]; then
    echo "  ⚠ Report not found: $REPORT_PATH"
    WARNINGS=$((WARNINGS+1))
  fi
  echo ""
fi

# ─── CICD MODE: Infrastructure verification ──────────────────────────────

if [[ "$MODE" == "cicd" ]]; then
  echo "[CICD] Infrastructure check..."
  # Check for secrets in staged changes
  SECRETS=$(git diff --cached 2>/dev/null | grep -ciE '(api_key|secret|token|password|bearer)\s*[:=]' || true)
  if [ "$SECRETS" -gt 0 ]; then
    echo "  ✗ BLOCKED: $SECRETS potential secrets found in staged changes"
    FAILURES=$((FAILURES+1))
  else
    echo "  ✓ No secrets detected in staged changes"
  fi
  echo ""
fi

# ─── SUMMARY ─────────────────────────────────────────────────────────────

echo ""
echo "==========================================="
if [ $FAILURES -gt 0 ]; then
  echo "  BLOCKED — $FAILURES failure(s), $WARNINGS warning(s)"
  echo "  Fix test failures before pushing."
  echo "==========================================="
  exit 1
elif [ $WARNINGS -gt 0 ]; then
  echo "  PROCEED WITH CAUTION — $WARNINGS warning(s)"
  echo "  Document why warnings are acceptable."
  echo "==========================================="
  exit 0
else
  echo "  VERIFIED ✓ — 0 failures, 0 warnings"
  echo "==========================================="
  exit 0
fi
