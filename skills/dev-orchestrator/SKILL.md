---
name: dev-orchestrator
description: >
  End-to-end AI development orchestrator. Single entry point for ALL tasks:
  features, bug fixes, refactors, research, CICD changes. Classifies task type,
  auto-detects tier, chains skills, enforces verification. Self-enforcing protocol.
  Use when: user says /dev, starts any task, or describes work to do.
---

# /dev — Self-Enforcing Development Protocol (v2)

One command to orchestrate the entire lifecycle for ANY task type.
Developer describes what they want → AI classifies, investigates, plans, executes,
verifies, and delivers — with structural enforcement at every phase.

```
UNDERSTAND ──[CHECKPOINT 1]──> BUILD ──[GATE]──> DELIVER ──[CHECKPOINT 2]──>
P0-P5                          P6-P7             P8-P10
```

---

## ENFORCEMENT: Phase Status Blocks (NON-NEGOTIABLE)

**Every phase MUST output a status block. Silent skipping = protocol violation.**

```
┌─ P<N>: <NAME> ────────────────────────────────
│ Status: DONE | SKIP <reason> | ADAPT <explanation>
│ Task: <type> | Tier: <tier>
│ Key actions: <what was done>
│ Next: P<N+1>
└────────────────────────────────────────────────
```

- SKIP is valid — but ONLY with a documented reason tied to task type.
- No status block = phase not executed = protocol violation.
- Output status blocks in conversation, NOT in plan files.

---

## P0: PRE-CHECK (Auto-Setup, runs once per project)

Show one-line status per check. Do NOT ask permission — just do it.

| Check | Action | DEVELOP | RESEARCH | CICD |
|-------|--------|---------|----------|------|
| **Git** | If not git repo, warn (worktrees won't work) | Required | Warn only | Required |
| **OpenSpec** | If `openspec/` missing → `openspec init --tools claude --profile core` | Auto-detect stack | Skip | Skip |
| **gitignore** | Append `openspec/changes/archive/` and `.worktrees/` if missing | Yes | Skip | Yes |
| **CLAUDE.md** | If project has none → create from README + dir structure | Yes | Skip | Yes |

"Project ready. Starting investigation..."

---

## P1: INVESTIGATE (Mandatory, ~5 min)

**Do NOT skip. Do NOT decide tier or type from keywords. Research BEFORE classifying.**

| Source | Action | When |
|--------|--------|------|
| **Memory** | `claudemem search "<keywords>" --compact --format json --limit 5` | Always |
| **Web** | Brave (direct lookups) or Exa (exploratory) per CLAUDE.md MCP table | Always |
| **Library docs** | context7 for frameworks/libraries involved | If applicable |
| **Current state** | API → fetch MCP; DB → postgres/mysql MCP; UI → playwright | If applicable |
| **Project context** | Read files, `openspec/specs/`, `git log --oneline -10` | Always |

Save key findings as claudemem notes **during** investigation, not after.

---

## P2: CLASSIFY (Mandatory, immediately after investigation)

Based on P1 evidence, classify **task type** and **tier**. Both MUST be in status block.

### Task Type

| Type | Evidence | Key Adaptation |
|------|----------|---------------|
| **DEVELOP** | Code change needed (feature, bug, refactor) | Full TDD + worktree + PR |
| **RESEARCH** | Investigate, document, analyze, learn | No TDD/worktree, keep brainstorm/verify/wrapup |
| **CICD** | Pipeline, infra, deploy, config change | No TDD, add dry-run + rollback verification |

If unclear → default to DEVELOP (safest — has all gates).

### Tier (evidence-based, NOT keyword-based)

| Evidence | Tier | Rationale |
|----------|------|-----------|
| Simple isolated change, no architectural impact | QUICK | Direct fix → Gate → commit |
| New capability or behavior change | STANDARD | Full phases, all gates |
| 3+ modules, architecture, unclear root cause | DEEP | Full phases + agent teams + CI wait + /wrapup |

Tier escalation: QUICK reveals design issue → auto-upgrade to STANDARD.

---

## Phase Adaptations by Task Type

| Phase | DEVELOP | RESEARCH | CICD |
|-------|---------|----------|------|
| **P0 PRE-CHECK** | Full setup | Git warn only | Git + CI config |
| **P1 INVESTIGATE** | Memory + code + docs | Memory + web + repo + docs | Memory + pipeline + infra |
| **P2 CLASSIFY** | → DEVELOP | → RESEARCH | → CICD |
| **P3 BRAINSTORM** | Intent + design trade-offs | Intent + deliverable scope | Impact + rollback strategy |
| **P4 SPECIFY** | `openspec-propose` | Research proposal | Change spec (what/why/rollback) |
| **P5 PLAN** | `writing-plans` (TDD tasks) | Research plan (questions + sources) | Change plan (steps + dry-run) |
| **P6 SETUP** | `using-git-worktrees` + baseline | Clone repo if needed | Backup current config/state |
| **P7 EXECUTE** | TDD per task + subagents | Investigate + real-time notes | Implement + dry-run + log |
| **P8 VERIFY** | Test suite + `verify-dev.sh` | Coverage + completeness check | Infra check + rollback test |
| **P9 SHIP** | Code review + PR + push | Deliver report + notes | Apply + monitor + /wrapup |
| **P10 ARCHIVE** | `openspec archive` + notes | claudemem + /wrapup + G/D/N | Notes + /wrapup + runbook |

---

## QUICK TIER (Bug fix / Small change)

**Skills**: systematic-debugging, test-driven-development, verification-before-completion

Flow: P1 → P2 → Root cause → TDD → Gate → commit.

1. **Root cause** — invoke `systematic-debugging` skill. If design issue → ESCALATE to STANDARD.
2. **TDD fix** — Follow TDD Protocol (below). Single task cycle.
3. **Gate** — `bash ~/.claude/scripts/verify-dev.sh`
4. **Commit + memory** — auto-commit, `claudemem note add` with root cause + fix.

QUICK tier outputs status blocks for P1, P2, and a combined P7-P9 block.

---

## DEEP TIER EXTRAS (on top of all standard phases)

| Extra | When | Action |
|-------|------|--------|
| **Deep Investigation** | Before P3 | `feature-dev:code-explorer` agents (2-3 parallel), claudemem sessions |
| **Agent Teams** | P7 if root cause unclear | 3-5 agents with competing hypotheses, disprove each other |
| **CICD Persistence** | After P9 | `gh run watch`, verify CI passes, fix if fails |
| **Deep Wrapup** | P10 | Detailed `/wrapup` session report, Goal/Done/Next by business objectives |

---

# STAGE 1: UNDERSTAND (P3-P5)

## P3: BRAINSTORM (STANDARD/DEEP — MANDATORY, NOT OPTIONAL)

**This is the FIRST skill invoked after classification. It determines everything downstream.**
Invoke `brainstorming` skill. Do NOT skip "because it seems simple."

| Task Type | Brainstorm Focus |
|-----------|-----------------|
| DEVELOP | User intent, design trade-offs, 2-3 approaches |
| RESEARCH | Deliverable scope, questions to answer, sources to check |
| CICD | Impact assessment, rollback strategy, blast radius |

## P4: SPECIFY (STANDARD/DEEP)

| Task Type | Action | Output |
|-----------|--------|--------|
| DEVELOP | Invoke `openspec-propose` | `openspec/changes/<name>/` with proposal.md + design.md |
| RESEARCH | Create research proposal | Questions, sources, deliverables, scope boundary |
| CICD | Create change spec | What changes, why, rollback plan, blast radius |

## P5: PLAN (STANDARD/DEEP)

| Task Type | Action | Output |
|-----------|--------|--------|
| DEVELOP | Invoke `writing-plans` with OpenSpec output | `docs/plans/YYYY-MM-DD-<name>.md`, each task = 2-5 min with TDD steps |
| RESEARCH | Create research plan | Questions to answer, sources per question, deliverable per section |
| CICD | Create change plan | Steps, dry-run command, verify command, rollback command |

### CHECKPOINT 1: Developer reviews plan/specs
Present plan summary via AskUserQuestion.
This is the ONLY human input before BUILD starts.

---

# STAGE 2: BUILD (P6-P7)

## P6: SETUP (STANDARD/DEEP)

| Task Type | Action |
|-----------|--------|
| DEVELOP | Invoke `using-git-worktrees`. Verify baseline tests pass. If baseline fails → STOP. |
| RESEARCH | Clone repo if needed (`gh repo clone`). No worktree. |
| CICD | Backup current config/state before making changes. |

## P7: EXECUTE

### DEVELOP: TDD Per Task

Invoke `subagent-driven-development` per task from plan:
1. **Implementer** — follows TDD Protocol | 2. **Spec reviewer** — compare vs specs
3. **Quality reviewer** — bugs, security (≥80% confidence) | 4. **Per-task verify** — full suite
5. **Auto-commit** — test + implementation together

**Agent Teams upgrade** (DEEP): if 3+ independent layers → `dispatching-parallel-agents`.

**Proactive MCP use**: context7 for APIs, fetch for endpoints, playwright for UI, DB MCPs for data.

### RESEARCH: Investigate + Notes

Per question from research plan:
1. Investigate via agents/search/MCPs (use `feature-dev:code-explorer` for DEEP)
2. **Save findings as claudemem notes IN REAL TIME** — `[noted: "title" -> category]`
3. Compile into report section
4. Verify: question answered with evidence?

### CICD: Implement + Dry-Run

1. Implement change | 2. Dry-run locally (`act`, `terraform plan`, etc.)
3. Auto-commit | 4. Log expected vs actual

### TDD Protocol (DEVELOP only, enforced per task)

| Step | Action | Required Output |
|------|--------|----------------|
| **RED** | Create test, run it | Output shows FAIL |
| **GREEN** | Implement minimum code, run test | Output shows PASS |
| **VERIFY** | Run full test suite | 0 new failures vs baseline |
| **COMMIT** | `git add` test + implementation | Descriptive commit message |

Evidence from RED/GREEN/VERIFY must be captured (paste output). Skipping = task not complete.

If test fails: RULE 2 (check test first) → RULE 3 (`systematic-debugging`) → RULE 6 (verify consumers).

### GATE: Verification Script

After all tasks: `bash ~/.claude/scripts/verify-dev.sh [--research|--cicd]`
- **BLOCKED** → return to P7. | **WARNING** → document reason. | **VERIFIED** → proceed.
- Do NOT proceed to DELIVER without VERIFIED or documented WARNING.

---

# STAGE 3: DELIVER (P8-P10)

## P8: VERIFY

Invoke `verification-before-completion` skill, then:

| Check | DEVELOP | RESEARCH | CICD |
|-------|---------|----------|------|
| **Evidence** | Fresh test output with counts | All questions answered? | Dry-run passes? |
| **Regression** | Baseline vs current (0 new failures) | Report coherent? | Rollback tested? |
| **Spec audit** | Re-read proposal.md scope | All sources checked? | No secrets exposed? |
| **Scope** | `git diff` — only expected files | Notes saved (count)? | Only expected config changed? |
| **Real-data** | Test with production-like data | Findings cross-referenced? | Health check post-change? |

If ANY check fails → loop back to P7.

## P9: SHIP

| Task Type | Steps |
|-----------|-------|
| **DEVELOP** | 1. Code review (`requesting-code-review`) → fix Critical/Important. 2. `verify-dev.sh` final gate. 3. `finishing-a-development-branch` → PR. 4. Push (ask user). 5. DEEP: `gh run watch`. |
| **RESEARCH** | 1. Self-review report for accuracy. 2. Deliver: report + claudemem notes. 3. Present Goal/Done/Next summary. |
| **CICD** | 1. Apply change (with user confirmation). 2. Monitor (`gh run watch` / health check). 3. Verify health. 4. Document in runbook if new pattern. |

### CHECKPOINT 2: Developer reviews deliverable
- DEVELOP: "PR ready with X/X tests passing, 0 regressions."
- RESEARCH: "Report complete, X notes saved, all questions answered."
- CICD: "Change applied, pipeline healthy, rollback documented."

## P10: ARCHIVE

| Action | DEVELOP | RESEARCH | CICD |
|--------|---------|----------|------|
| **Specs** | `/opsx:archive` (STANDARD/DEEP) | N/A | N/A |
| **Memory** | `claudemem note add` summary | `claudemem note add` findings | `claudemem note add` change |
| **Worktree** | Cleanup if used | N/A | N/A |
| **Wrapup** | `/wrapup` (DEEP) | `/wrapup` (STANDARD/DEEP) | `/wrapup` (DEEP) |
| **Summary** | Goal/Done/Next | Goal/Done/Next | Goal/Done/Next |

---

## PLAN MODE INTEGRATION

When Plan Mode is active simultaneously with /dev:
1. **/dev's workflow takes PRIORITY** over Plan Mode's 5-phase workflow
2. Use Plan Mode's file as output location for /dev's plan (P5)
3. Map: Plan Mode "Understand" = /dev P0-P5, Plan Mode "Design" = /dev P5
4. Status blocks go in conversation output (not plan file)
5. Use AskUserQuestion for /dev checkpoints (CHECKPOINT 1 & 2)
6. Call ExitPlanMode after P5 (CHECKPOINT 1 approved) to begin BUILD stage

---

## THE 7 VERIFICATION RULES

| Rule | Text | Enforcement |
|------|------|-------------|
| **R1: DOUBLE-VERIFY** | Every "done" needs fresh evidence. Never "should work." | verify-dev.sh (DEVELOP), coverage check (RESEARCH) |
| **R2: AUDIT-DRIVEN** | Test fails? Check TEST first, then CODE. | TDD Protocol VERIFY step |
| **R3: ROOT CAUSE** | Don't fix symptoms. Surface or design-level? | P1 investigation + tier escalation |
| **R4: REGRESSION** | After EVERY change, run FULL test suite. | TDD VERIFY + verify-dev.sh |
| **R5: CICD** | "Done" = passes locally AND CI passes. | verify-dev.sh + DEEP CI wait |
| **R6: CLOSED-LOOP** | Created file → verify imported. Changed config → verify consumers. | verify-dev.sh scope check |
| **R7: CROSS-SESSION** | Before: claudemem search. After: note + archive + /wrapup. | P1 (before) + P10 (after) |

---

## OVERRIDE FLAGS

| Flag | Effect |
|------|--------|
| `--quick` | Force QUICK tier (skip brainstorm/spec/plan) |
| `--deep` | Force DEEP tier (maximum thoroughness) |
| `--no-spec` | Skip OpenSpec (refactors, non-behavioral) |
| `--no-pr` | Auto-commit without PR (quick fixes on feature branches) |
| `--research` | Force RESEARCH task type |
| `--cicd` | Force CICD task type |
