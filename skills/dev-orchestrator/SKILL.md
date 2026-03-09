---
name: dev-orchestrator
description: >
  End-to-end AI development orchestrator. Single entry point for ALL development
  tasks: features, bug fixes, refactors, CICD changes. Auto-detects task tier
  via investigation, chains all available skills, enforces verification rules.
  Use when: user says /dev, starts any development task, or describes work to do.
---

# /dev — Enforced Development Protocol

One command to orchestrate the entire development lifecycle.
Developer describes what they want → AI investigates, plans, implements,
verifies, and ships — with structural enforcement at every stage.

**Developer touches the keyboard twice:**
1. Review plan/specs — confirm direction is right
2. Review PR — approve to merge

Everything between is automated and enforced.

```
UNDERSTAND ──[CHECKPOINT 1]──> BUILD ──[GATE]──> DELIVER ──[CHECKPOINT 2]──>
```

---

## PRE-CHECK: Auto-Setup (runs once per project, silently)

Show one-line status for each check. Do NOT ask for permission — just do it.

1. **Git**: If not a git repo, warn developer (worktrees won't work).

2. **OpenSpec**: If `openspec/` directory does NOT exist:
   - Run: `openspec init --tools claude --profile core`
   - Auto-detect tech stack from project files:
     - `package.json` → Node.js/TypeScript, detect framework
     - `requirements.txt` / `pyproject.toml` → Python, detect framework
     - `Cargo.toml` → Rust | `go.mod` → Go | `pom.xml` / `build.gradle` → Java
   - Create `openspec/config.yaml` based on `~/.claude/templates/openspec-config.yaml`

3. **gitignore**: If `.gitignore` doesn't contain `openspec/changes/archive/`:
   - Append: `openspec/changes/archive/` and `.worktrees/`

4. **Project CLAUDE.md** (first-time only): If none exists, create from:
   - README.md (project description), directory structure, package manager files
   - Content: purpose, tech stack, key directories, test command

"Project ready. Starting investigation..."

---

## PHASE 0: INVESTIGATE (Mandatory, ~5 min)

**Do NOT skip. Do NOT decide tier from keywords.**

```bash
claudemem search "<task keywords>" --compact --format json --limit 5
# If relevant: claudemem note get <id>
# Concept search: claudemem search "<keywords>" --semantic --compact --format json --limit 5
```

Read relevant files, check `openspec/specs/`, check `git log --oneline -10`.

**Tier detection (evidence-based):**

| Evidence | Tier | Rationale |
|----------|------|-----------|
| Simple isolated change, no architectural impact | QUICK | Direct TDD fix |
| New capability or behavior change | STANDARD | Needs specs + structured implementation |
| 3+ modules, CICD, architecture, unclear root cause | DEEP | Deep exploration + multi-agent |

Tier escalation: QUICK reveals design issue → auto-upgrade to STANDARD.

---

## TIER FLOWS

### QUICK TIER (Bug fix / Small change, ~5-15 min)

**Skills: systematic-debugging, test-driven-development, verification-before-completion**

Flow: Phase 0 → Root cause → TDD Protocol → Gate → commit.

1. **Root cause investigation** — invoke `systematic-debugging` skill
   - Phase 1: Read errors, reproduce, gather evidence
   - Phase 2: Find working examples, compare
   - Phase 3: Form ONE hypothesis, test minimally
   - RULE 3: Root cause > patches. Design issue or surface bug?
   - If design issue → ESCALATE to STANDARD tier
2. **TDD fix** — Follow TDD Protocol (below). Single task cycle.
3. **Gate** — `bash ~/.claude/scripts/verify-dev.sh`
4. **Commit + memory** — auto-commit, `claudemem note add` with root cause + fix.

### STANDARD TIER (Feature development)

All 7 phases, all gates.

### DEEP TIER (Complex system change, ~2-8 hours)

All 7 phases + these extras:

**Extra: Deep Investigation** (before Phase 1)
- Invoke `feature-dev:code-explorer` agents (2-3 in parallel) to deeply analyze codebase
- Check claudemem for related sessions/notes
- Check Notion for related tasks/docs
- SSM into EC2 if applicable (runtime state, not just code)

**Extra: Agent Teams for Debugging** (during Phase 4)
If root cause unclear after investigation:
- Spawn 3-5 Agent Team teammates with competing hypotheses
- Each teammate investigates a different theory
- Teammates actively try to DISPROVE each other
- Surviving theory = actual root cause

**Extra: CICD Persistence** (after Phase 6)
- Wait for CI pipeline to complete (`gh run watch`)
- Verify CI passes (not just local tests)
- If CI fails: investigate, fix, re-push
- RULE 5: Changes only "done" when CI passes

**Extra: Deep Memory Wrapup** (Phase 7)
- Detailed session report via `/wrapup`
- Save architectural decisions to claudemem
- Goal/Done/Next organized by business objectives

---

# STAGE 1: UNDERSTAND

Contains Phase 0, Phase 1, Phase 2.

## Phase 1: SPECIFY (STANDARD/DEEP only)

Invoke `openspec-propose` skill → creates proposal.md, specs/, design.md, tasks.md.

## Phase 2: PLAN (STANDARD/DEEP only)

Invoke `writing-plans` skill with OpenSpec output as input.
Each task = 2-5 min. Each task MUST include: what test to write, what to implement, what to verify.
Save plan to `docs/plans/YYYY-MM-DD-<name>.md`.

### CHECKPOINT 1: Developer reviews plan/specs

Present plan summary. Use AskUserQuestion.
"Here are the specs and plan. Review and confirm, or tell me what to change."

This is the ONLY human input before BUILD starts.

---

# STAGE 2: BUILD

Contains Phase 3, Phase 4.

## Phase 3: SETUP (STANDARD/DEEP only)

Invoke `using-git-worktrees` skill. Create isolated worktree, verify baseline tests pass.
If baseline fails → STOP and investigate.

## Phase 4: EXECUTE

Per task from the plan, invoke `subagent-driven-development` skill:

1. **Implementer subagent** — follows TDD Protocol (below)
2. **Spec reviewer subagent** — compare against OpenSpec specs
3. **Quality reviewer subagent** — bugs, security, patterns (≥80% confidence)
4. **Per-task verify** — full test suite after each task
5. **Auto-commit** — test file + implementation file together

**Agent Teams upgrade** — if 3+ independent layers, spawn Agent Teams.

If test fails:
- RULE 2: Is the TEST wrong or the CODE wrong?
- RULE 3: `systematic-debugging` before patching.
- RULE 6: Verify all consumers updated.

### TDD Protocol (enforced, every task)

This is a PROTOCOL — fixed sequence, not optional. Same enforcement level as
claudemem's session report template. Skipping any step = task not complete.

```
STEP 1 — RED
  Create test file for this task.
  Run test. Capture output.
  REQUIRED: Output shows FAIL.
  If test passes → test is wrong. Fix test first.

STEP 2 — GREEN
  Implement the minimum code to pass the test.
  Run test. Capture output.
  REQUIRED: Output shows PASS.

STEP 3 — VERIFY
  Run project's full test suite.
  REQUIRED: 0 new failures vs baseline.
  If regression → RULE 2: audit test first, then code.

STEP 4 — COMMIT
  git add both test file AND implementation file.
  Auto-commit with descriptive message.
```

Evidence from steps 1-3 must be captured (paste output in response).

### GATE: Verification Script (automated, mandatory)

After all tasks complete, run:

```bash
bash ~/.claude/scripts/verify-dev.sh
```

This enforces RULE 1 (tests pass), RULE 4 (new code has tests), RULE 6 (scope check).

- **BLOCKED** → return to Phase 4, fix failures.
- **WARNING** → document reason, then proceed.
- **VERIFIED** → proceed to Stage 3.

Do NOT proceed to DELIVER without VERIFIED or documented WARNING.

---

# STAGE 3: DELIVER

Contains Phase 5, Phase 6, Phase 7.

## Phase 5: DOUBLE-VERIFY

Invoke `verification-before-completion` skill, then:

1. **Evidence-first**: Fresh test suite output with specific counts.
2. **Regression scan**: Compare baseline vs current — any new failures = investigate.
3. **Spec audit** (STANDARD/DEEP): Re-read proposal.md scope → nothing missed?
4. **Scope check**: `git diff` — only expected files changed?

If ANY check fails → loop back to Phase 4.

## Phase 6: SHIP

1. **Mandatory code review**: Dispatch `requesting-code-review` subagent.
   This is NOT optional. Skipping = skipping Phase 6.
   - Fix Critical issues immediately.
   - Fix Important issues before proceeding.
   - Minor/Style: fix or document why deferred.
2. **Final gate**: `bash ~/.claude/scripts/verify-dev.sh` one more time.
3. **Create PR**: `finishing-a-development-branch` skill.
   PR body: Summary, Specs link, Test Evidence (pasted output), Tasks Completed.
4. **Push** to remote.

### CHECKPOINT 2: Developer reviews PR

"PR ready with X/X tests passing, 0 regressions. Review and approve."

This is the ONLY human input after BUILD.

## Phase 7: ARCHIVE

1. `/opsx:archive` — merge delta specs into openspec/specs/ (STANDARD/DEEP).
2. `claudemem note add` — save change summary + key decisions.
3. Cleanup worktree if used.
4. Present Goal/Done/Next summary.

---

## THE 7 VERIFICATION RULES

Non-negotiable. Rules 1, 4, 5, 6 are enforced by `verify-dev.sh`.
Rules 2, 3, 7 are enforced by the Protocol and Phase structure.

| Rule | Text | Enforcement |
|------|------|-------------|
| **1: DOUBLE-VERIFY** | Every "done" needs fresh test output with counts. Never "should work." | verify-dev.sh runs full test suite |
| **2: AUDIT-DRIVEN** | Test fails? Check TEST first, then CODE. | TDD Protocol Step 3 |
| **3: ROOT CAUSE** | Don't fix symptoms. Surface or design-level? | Phase 0 investigation + tier escalation |
| **4: REGRESSION** | After EVERY change, run FULL test suite. | TDD Protocol Step 3 + verify-dev.sh |
| **5: CICD** | "Done" = tests pass locally AND CI passes. | verify-dev.sh + DEEP tier CI wait |
| **6: CLOSED-LOOP** | Created file → verify imported. Changed config → verify consumers. | verify-dev.sh scope check |
| **7: CROSS-SESSION** | Before: claudemem search + openspec/specs/. After: note + archive. | Phase 0 (before) + Phase 7 (after) |

---

## OVERRIDE FLAGS

- `/dev --quick` — Force QUICK tier (skip investigation)
- `/dev --deep` — Force DEEP tier (maximum thoroughness)
- `/dev --no-spec` — Skip OpenSpec (for non-behavioral changes like refactors)
- `/dev --no-pr` — Auto-commit without PR (for quick fixes on feature branches)
