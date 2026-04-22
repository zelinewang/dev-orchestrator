#!/usr/bin/env bash
# PostToolUse:Edit|Write hook — auto-format Python files after edits.
# Part of /dev v4 workflow system. Non-blocking (errors are silent).
# Compatible with Opus 4.6/4.7.
# Obsolescence condition: when pre-commit hooks cover all formatting.
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Only Python files
case "$FILE_PATH" in
  *.py)
    if command -v ruff &>/dev/null; then
      ruff format --quiet "$FILE_PATH" 2>/dev/null || true
    elif command -v black &>/dev/null; then
      black --quiet "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
