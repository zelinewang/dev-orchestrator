---
name: dev-orchestrator
description: >
  End-to-end AI development orchestrator. Single entry point for ALL development
  tasks: features, bug fixes, refactors, CICD changes. Auto-detects task tier
  via investigation, chains all available skills, enforces verification rules.
  Use when: user says /dev, starts any development task, or describes work to do.
---

# /dev — Full-Stack Development Orchestrator

One command to orchestrate the entire development lifecycle. Developer describes
what they want → AI investigates, plans, implements, verifies, and ships.

**Developer touches the keyboard twice:**
1. Review specs (2 min) — confirm direction is right
2. Review PR (final check) — approve to merge

Everything between is automated.

---

## PHASE 0: INVESTIGATE BEFORE DECIDING (Mandatory, ~5 min)

**Do NOT skip this phase. Do NOT decide tier from keywords alone.**

The optimal tool stack depends on the ACTUAL nature of the problem, not the
DESCRIBED nature. You cannot know without investigating first.

```bash
claudemem search "<task keywords>" --format json --limit 5
```

Then read relevant files, check `openspec/specs/` for existing behavior,
check `git log --oneline -10` for recent changes.

**Assess and recommend tier with evidence:**

| Evidence Found | Tier | Rationale |
|----------------|------|-----------|
| Simple isolated change, no architectural impact | QUICK | Direct TDD fix sufficient |
| New capability or behavior change needed | STANDARD | Needs specs + structured implementation |
| Touches 3+ modules, CICD, architecture, or root cause unclear | DEEP | Needs deep exploration + multi-agent |

Present recommendation to developer: "Based on investigation, I recommend [TIER]
because [evidence]. Override with --quick or --deep if you disagree."

**Tier escalation:** If QUICK investigation reveals deeper issue → auto-upgrade.
"This looked like a simple bug but investigation shows an architectural issue.
Upgrading to STANDARD with OpenSpec specs."

---

## QUICK TIER (Bug fix / Small change, ~5-15 min)

**Skills: systematic-debugging, test-driven-development, verification-before-completion**

1. **Root cause investigation** — invoke `systematic-debugging` skill
   - Phase 1: Read errors, reproduce, gather evidence
   - Phase 2: Find working examples, compare
   - Phase 3: Form ONE hypothesis, test minimally
   - RULE 3: Root cause > patches. Ask: design issue or surface bug?
   - If design issue → ESCALATE to STANDARD tier

2. **TDD fix** — invoke `test-driven-development` skill
   - RED: Write failing test capturing the bug
   - GREEN: Implement minimal fix
   - REFACTOR: Clean up

3. **Verify** — apply RULE 1 (Double-Verify) + RULE 4 (Regression Paranoia)
   - Run FULL test suite, not just the new test
   - Capture output with specific counts
   - If regression: RULE 2 (Audit-Driven) — check test first, then code

4. **Commit** — auto-commit with descriptive message
5. **Memory** — `claudemem note add` with root cause + fix summary

---

## STANDARD TIER (Feature development, ~30-120 min)

### Phase 1: SPECIFY
**Skills: OpenSpec**

Invoke `/opsx:propose <change-name>` (use the `openspec-propose` skill).
This creates: proposal.md, specs/, design.md, tasks.md

**CHECKPOINT 1:** Present specs summary to developer.
Use **AskUserQuestion**: "Here are the specs. Review and confirm, or tell me
what to add/change/remove."

### Phase 2: PLAN
**Skills: superpowers:writing-plans**

Load OpenSpec's design.md + tasks.md as input.
Invoke `writing-plans` skill to generate granular TDD plan.
Each task = 2-5 min, each includes: write test → implement → verify → commit.
Save plan to `docs/plans/YYYY-MM-DD-<name>.md`.

### Phase 3: SETUP
**Skills: superpowers:using-git-worktrees**

Invoke `using-git-worktrees` skill.
Create isolated worktree, install deps, verify baseline tests pass.
If baseline fails → STOP and investigate before proceeding.

### Phase 4: EXECUTE
**Skills: superpowers:subagent-driven-development, test-driven-development, systematic-debugging**

Invoke `subagent-driven-development` skill. Per task:

1. **Implementer subagent** — TDD cycle (RED → GREEN → REFACTOR)
2. **Spec reviewer subagent** — compare against OpenSpec specs
3. **Quality reviewer subagent** — bugs, security, patterns (≥80% confidence)
4. **Per-task verify** — RULE 1 + RULE 4: full test suite, check regressions
5. **Auto-commit** after each task

If test fails during execution:
- RULE 2 (Audit-Driven): Is the test wrong or the code wrong?
- RULE 3 (Root Cause): systematic-debugging before patching
- RULE 6 (Closed-Loop): verify all consumers updated

**Agent Teams upgrade** — if task involves 3+ independent layers:
Spawn Agent Teams instead of subagents. Each teammate owns a layer.
Teammates coordinate interfaces via mailbox. No file conflicts.

### Phase 5: DOUBLE-VERIFY
**Skills: superpowers:verification-before-completion**

Invoke `verification-before-completion` skill, then additionally:

1. **Evidence-first**: Run full test suite → capture output with counts
2. **Regression scan**: Compare baseline vs current. Any new failures = investigate
3. **Spec audit**: Re-read proposal.md scope → check nothing missed
4. **Scope check**: `git diff` — only expected files changed?

If ANY verification fails → loop back to Phase 4.

### Phase 6: SHIP
**Skills: superpowers:requesting-code-review, superpowers:finishing-a-development-branch**

1. Invoke `requesting-code-review` — dispatch reviewer subagent
   - Fix Critical issues immediately, Important before proceeding
2. Invoke `finishing-a-development-branch` — create PR
   - PR body includes: Summary, Specs link, Test Evidence, Tasks Completed
3. Push to remote

**CHECKPOINT 2:** Present PR to developer.
"PR is ready with X/X tests passing, no regressions. Review and approve."

### Phase 7: ARCHIVE
**Skills: OpenSpec, claudemem**

1. `/opsx:archive` — merge delta specs into openspec/specs/
2. `claudemem note add` — save change summary + key decisions
3. Cleanup worktree
4. Present Goal/Done/Next summary

---

## DEEP TIER (Complex system change, ~2-8 hours)

Same as STANDARD, plus these additions:

### Extra: Deep Investigation (before Phase 1)
- Invoke `feature-dev:code-explorer` agents (2-3 in parallel) to deeply analyze codebase
- Check claudemem for related sessions/notes
- Check Notion for related tasks/docs
- SSM into EC2 if applicable (runtime state, not just code)

### Extra: Agent Teams for Debugging
If root cause unclear after investigation:
- Spawn 3-5 Agent Team teammates with competing hypotheses
- Each teammate investigates a different theory
- Teammates actively try to DISPROVE each other
- Surviving theory = actual root cause

### Extra: CICD Persistence (after Phase 6)
- Wait for CI pipeline to complete (`gh run watch`)
- Verify CI passes (not just local tests)
- If CI fails: investigate, fix, re-push
- RULE 5: Changes only "done" when CI passes

### Extra: Deep Memory Wrapup
- Detailed session report via `/wrapup`
- Save architectural decisions to claudemem
- Goal/Done/Next organized by business objectives

---

## THE 7 VERIFICATION RULES (Apply to ALL tiers)

These are NON-NEGOTIABLE. Apply automatically at every relevant phase.

**RULE 1: DOUBLE-VERIFY** — Every "done" claim needs fresh test output with
specific counts. Never say "should work" or "seems to pass."

**RULE 2: AUDIT-DRIVEN FIXING** — Test fails? Check if TEST is wrong first
(wrong assertion, outdated expectation), then check if CODE is wrong.

**RULE 3: ROOT CAUSE DEPTH** — Don't fix symptoms. Ask: surface issue or
design-level? Will this fix survive the next 10 changes? If deeper issue
found, escalate tier.

**RULE 4: REGRESSION PARANOIA** — After EVERY code change, run FULL test
suite. New failure = instant investigation. Don't proceed.

**RULE 5: CICD AWARENESS** — Changes only "done" when tests pass locally
AND CI passes. For DEEP tier, verify deployed state too.

**RULE 6: CLOSED-LOOP COMPLETION** — Every cycle closes its own loop.
Created file → verify imported. Changed config → verify consumers updated.
Added port → verify routing updated. Like K8s: single source of truth.

**RULE 7: CROSS-SESSION PERSISTENCE** — Before: claudemem search + check
openspec/specs/. After: claudemem note + /opsx:archive + Goal/Done/Next.

---

## OVERRIDE FLAGS

- `/dev --quick` — Force QUICK tier (skip investigation)
- `/dev --deep` — Force DEEP tier (maximum thoroughness)
- `/dev --no-spec` — Skip OpenSpec (for non-behavioral changes like refactors)
- `/dev --no-pr` — Auto-commit without PR (for quick fixes on feature branches)
