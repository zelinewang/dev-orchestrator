#!/usr/bin/env bash
# PostToolUse:Bash hook — TDD commit pairing nudge.
#
# Smart, advisory enforcement of tdd-protocol.md rule:
# "Commit test + implementation together, one logical unit per subtask."
#
# Triggers ONLY on:
#   - Bash command containing "git commit" (not amend, not merge, not rebase)
#   - Commit message starting with feat:/feat(...):/fix:/fix(...):
#     (TDD-relevant types only — skips docs:, chore:, ci:, build:, etc.)
#
# When triggered, checks last commit:
#   - Has source-code changes (.py/.js/.ts/.go/.rs/etc.)?
#   - Has test changes (test_*, _test., .spec., tests/)?
#
# If source WITHOUT test → emit additionalContext nudge.
# Non-blocking (no exit 2). Trusts agent to override for legit hotfix/refactor.
#
# Justification: skill-comply baseline 2026-04-27 showed
# commit_test_and_implementation step at 0% across all 3 scenarios. Real-world
# commits in this repo: 22% mixed (test+impl), 78% impl-only or test-only.
# Hook converts "rule never followed" → "rule prompted on every relevant commit".
#
# Compatible with Opus 4.6/4.7. Obsolescence condition: when post-baseline
# remeasurement shows >70% mixed-commit rate naturally.
set -euo pipefail

INPUT=$(cat)

# All processing in one Python invocation — no shell injection surface, no leaky
# variables, no grep edge cases on filenames with spaces.
INPUT_BODY="$INPUT" python3 - <<'PY' 2>/dev/null || true
import json
import os
import re
import subprocess
import sys

raw = os.environ.get("INPUT_BODY", "")
if not raw:
    sys.exit(0)
try:
    data = json.loads(raw)
except Exception:
    sys.exit(0)

cmd = (data.get("tool_input") or {}).get("command", "")
if "git commit" not in cmd:
    sys.exit(0)

# Skip non-TDD-relevant commit operations
if re.search(r"--amend|--no-edit|merge|rebase|cherry-pick|revert", cmd):
    sys.exit(0)

# Verify the commit actually happened (PostToolUse fires whether tool succeeded or not)
try:
    msg_proc = subprocess.run(
        ["git", "log", "-1", "--format=%s"],
        capture_output=True, text=True, timeout=5,
    )
    if msg_proc.returncode != 0:
        sys.exit(0)
    commit_msg = msg_proc.stdout.strip()
except Exception:
    sys.exit(0)

# Only fire on TDD-relevant commit types
if not re.match(r"^(feat|fix)(\([^)]+\))?:", commit_msg):
    sys.exit(0)

# Get files changed in last commit
try:
    files_proc = subprocess.run(
        ["git", "show", "--name-only", "--format=", "HEAD"],
        capture_output=True, text=True, timeout=5,
    )
    if files_proc.returncode != 0:
        sys.exit(0)
    files = [f for f in files_proc.stdout.strip().split("\n") if f]
except Exception:
    sys.exit(0)

# Classify files
TEST_RE = re.compile(
    r"(^|/)test_|"          # test_foo.py
    r"_test\.[a-z]+$|"       # foo_test.go
    r"\.test\.[a-z]+$|"      # foo.test.ts
    r"\.spec\.[a-z]+$|"      # foo.spec.ts
    r"(^|/)tests?/"          # tests/foo.py or test/foo.py
)
SOURCE_RE = re.compile(r"\.(py|js|jsx|ts|tsx|go|rs|java|kt|swift|rb|php|c|cpp|h|hpp)$")

test_files = [f for f in files if TEST_RE.search(f)]
source_files = [f for f in files if SOURCE_RE.search(f) and not TEST_RE.search(f)]

# Only nudge when source code committed WITHOUT corresponding test changes
if source_files and not test_files:
    short_msg = commit_msg[:60] + ("..." if len(commit_msg) > 60 else "")
    n_src = len(source_files)
    nudge = (
        f"TDD pairing nudge (advisory): commit '{short_msg}' modified "
        f"{n_src} source file(s) but no test changes. The tdd-protocol rule "
        f"says: commit test + implementation together as one logical unit. "
        f"Skill-comply baseline showed this step at 0% — that's why this hook "
        f"exists. If TDD applies to this change, amend or include test in "
        f"next commit. If genuinely impl-only (hotfix, refactor with existing "
        f"tests, config), this is fine — proceed."
    )
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": nudge,
    }}))
PY

exit 0
