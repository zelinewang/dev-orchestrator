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

## CONTINUITY CONTRACT (end-to-end auto-run)

**Once /dev starts, it owns the task until P10 ARCHIVE, or a CHECKPOINT, or an
explicit error escalation.** This contract governs when /dev pauses vs continues.

### /dev MUST NOT stop between phases just because a phase finished.
Proceed directly from P<N> status block to P<N+1> without user prompting,
unless one of the three legitimate pause reasons below applies.

### Three legitimate pauses (the ONLY ones)

1. **CHECKPOINT 1** (after P5 PLAN) — human approves the plan before BUILD
2. **CHECKPOINT 2** (after P9 SHIP) — human reviews deliverable before push/merge
3. **External wait** (CI, long build, agent teams, deploy health) — enters a
   LOOP pattern via `ScheduleWakeup`, automatically resumes on signal

Any other "stop and ask" is a protocol violation. If you find yourself unsure
→ pick the safer default and note it in the next status block, don't halt.

### Auto-Loop Default (STANDARD and DEEP tiers)

- **STANDARD / DEEP**: Loop is **automatically enabled** in every phase that
  has an "external wait" signal. User does NOT need to pass `--loop`.
- **QUICK**: Loop is **automatically disabled** — every QUICK-tier work is by
  definition short enough to block on without cache cost.
- **Override**: `--no-loop` forces blocking mode even on STANDARD/DEEP (useful
  when the user wants to watch CI live rather than cede control to the loop).

### End-to-End Sequencing Examples

**DEEP DEVELOP task with CI**:
```
P0 → P1 → P2 → P3 → P4 → P5 → [CHECKPOINT 1: pause for human]
↓ (approved)
P6 → P7 (TDD per task, Agent Teams may auto-loop at merge point)
  → P8 (verify; if long-running → auto-loop Pattern 2)
  → P9 (push PR; auto-enter LOOP Pattern 1 for CI wait)
  → [CI green] → [CHECKPOINT 2: pause for human]
↓ (approved)
P10 → DONE (session ends gracefully)
```

**STANDARD DEVELOP task without CI wait**:
```
P0 → P1 → P2 → P3 → P4 → P5 → [CHECKPOINT 1] → ... → P9 (push) → [CHECKPOINT 2] → P10 → DONE
```
No loop invocation needed (no external waits), but the /dev session still runs
end-to-end without user needing to say "continue" between phases.

### Why this matters

Without this contract, /dev stops 10+ times in a DEEP task ("P1 done, continue?"
"P3 done, continue?"). With it, /dev stops 2-3 times total: the two CHECKPOINTs
and any loop-failure escalations. User cognitive load drops by 5-10×.

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

### Loop Wake Status Block (when ScheduleWakeup-driven iteration is active)

When a phase uses `ScheduleWakeup` (see LOOP INTEGRATION section), each wake
MUST emit a loop-specific block BEFORE the regular phase block:

```
┌─ LOOP WAKE: P<N>/<phase-name> (iter <k>/<max>) ─
│ Elapsed: <m>m | Next delay: <s>s (cache <hit|miss>)
│ Signal: <pending|pass|fail|timeout|unknown>
│ Exit target: <success cond> | <fail cond>
│ Action this cycle: <what was done this wake>
│ Decision: <continue|exit-success|exit-failure|exit-escalate>
└────────────────────────────────────────────────
```

If `iter >= max` or `cost cap hit` → Decision MUST be `exit-failure` or
`escalate`. Do NOT silently continue past the declared cap.

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
| **Skills** | Scan available skills list in system context. Identify domain-specific skills whose `description` matches the task (e.g., `social-investigator` for social media, `claude-api` for Anthropic SDK). Add matched skills to P7 execution plan as tool sources. | Always |
| **Search-first** | Invoke ECC `search-first` skill — search for existing tools, libraries, patterns before writing custom code | DEVELOP tasks |
| **Web** | Brave (direct lookups) or Exa (exploratory) per CLAUDE.md MCP table | Always |
| **Library docs** | context7 for frameworks/libraries involved | If applicable |
| **Current state** | API → fetch MCP; DB → postgres/mysql MCP; UI → playwright | If applicable |
| **Project context** | Read files, `openspec/specs/`, `git log --oneline -10` | Always |

### Language/Framework Detection (for DEVELOP tasks)

Detect primary project language to enable language-aware agent delegation in P7/P9:

| Indicator File | Language | ECC Reviewer Agent | ECC Build Resolver |
|---------------|----------|-------------------|-------------------|
| `package.json` / `tsconfig.json` | TypeScript | `typescript-reviewer` | `build-error-resolver` |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python | `python-reviewer` | — |
| `go.mod` | Go | `go-reviewer` | `go-build-resolver` |
| `Cargo.toml` | Rust | `rust-reviewer` | `rust-build-resolver` |
| `pom.xml` / `build.gradle.kts` (Java) | Java | `java-reviewer` | `java-build-resolver` |
| `build.gradle.kts` (Kotlin) | Kotlin | `kotlin-reviewer` | `kotlin-build-resolver` |
| `CMakeLists.txt` / `*.cpp` | C++ | `cpp-reviewer` | `cpp-build-resolver` |
| `Package.swift` | Swift | — | — |
| `pubspec.yaml` | Flutter/Dart | `flutter-reviewer` | — |

Record detected language in P2 status block. If mixed-language, note primary + secondary.

### Source Evaluation (applied to ALL P1 findings)

External information (web search, DeepWiki, API responses, LLM summaries) is input, NOT truth.

**Before any P1 finding influences P2-P10 decisions**:
1. **Verify load-bearing claims** against primary sources (source code > official docs > AI summaries)
2. **Flag source type**: primary (code/docs), community (wikis/tutorials), AI-generated (DeepWiki/LLM), opinion (blogs/forums)
3. **Check for bias/agenda**: Is the source promoting something? Selling something? Competing?
4. **Cross-reference** when claims conflict — trust what you can directly observe over what others describe
5. **Note confidence level** in status block: "P1 finding X (high confidence — verified in source code)" vs "P1 finding Y (medium — from DeepWiki, not verified)"

If a decision in P3-P7 depends on an unverified external claim → verify first or flag uncertainty.

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
| **CICD Persistence (auto)** | After P9 | **Automatically** enters `ScheduleWakeup` LOOP Pattern 1 (CI wait) — NOT blocking `gh run watch`. User does not need to pass `--loop`. Verify CI passes, auto-spawn fix cycle if CI fails. See LOOP INTEGRATION + CONTINUITY CONTRACT. |
| **Deep Wrapup** | P10 | Detailed `/wrapup` session report, Goal/Done/Next by business objectives |

---

# STAGE 1: UNDERSTAND (P3-P5)

## P3: BRAINSTORM (STANDARD/DEEP — MANDATORY, NOT OPTIONAL)

**This is the FIRST skill invoked after classification. It determines everything downstream.**
Invoke `brainstorming` skill. Do NOT skip "because it seems simple."
**DEEP tier**: additionally invoke ECC `architect` agent for architecture review and ADR generation.

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

### DEVELOP: TDD Per Task (Language-Aware)

Invoke `subagent-driven-development` per task from plan:
1. **Implementer** — follows TDD Protocol (use `tdd-guide` agent from ECC when available)
2. **Spec reviewer** — compare vs specs
3. **Quality reviewer** — use language-specific ECC reviewer agent (detected in P1):
   - TypeScript → `typescript-reviewer` | Python → `python-reviewer` | Go → `go-reviewer`
   - Rust → `rust-reviewer` | Java → `java-reviewer` | Kotlin → `kotlin-reviewer`
   - C++ → `cpp-reviewer` | Flutter → `flutter-reviewer` | Mixed/other → `code-reviewer`
4. **Per-task verify** — full suite
5. **Auto-commit** — test + implementation together
6. **On build failure** — use language-specific ECC build resolver agent if available

**Agent Teams upgrade** (DEEP): if 3+ independent layers → `dispatching-parallel-agents`.

**Database changes**: if task involves SQL/ORM/migrations → add `database-reviewer` agent to quality team.

**Proactive MCP use**: context7 for APIs, fetch for endpoints, playwright for UI, DB MCPs for data.

**Long-running work → ScheduleWakeup loop** (see LOOP INTEGRATION):
- Docker build >3 min, heavy test suites, background subagent teams, remote pipelines
- Start the work with `run_in_background: true` OR `Task` in background OR `Monitor`, then call `ScheduleWakeup` with LOOP Pattern 2 (Long task) or Pattern 3 (Agent merge)
- Each wake: read `BashOutput` / `TaskOutput`, decide continue vs exit
- Do NOT sit idle blocking on long builds — context dies faster than you wait

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

Invoke `/verify` command (9-phase unified verification with Iron Law — supersedes
`verification-before-completion` + `verification-loop` skills). For DEVELOP tasks,
run `/verify` with project auto-detection. For RESEARCH/CICD, run manual checks below.
Then verify:

| Check | DEVELOP | RESEARCH | CICD |
|-------|---------|----------|------|
| **Evidence** | Fresh test output with counts | All questions answered? | Dry-run passes? |
| **Regression** | Baseline vs current (0 new failures) | Report coherent? | Rollback tested? |
| **Spec audit** | Re-read proposal.md scope | All sources checked? | No secrets exposed? |
| **Scope** | `git diff` — only expected files | Notes saved (count)? | Only expected config changed? |
| **Real-data** | Test with production-like data | Findings cross-referenced? | Health check post-change? |

If ANY check fails → loop back to P7.

**Long-running verify via ScheduleWakeup** (LOOP Pattern 2): If `/verify` includes
a heavy step (full integration suite, docker build + e2e, browser visual diff)
that runs >2 min:
- Start it in background (`run_in_background: true` or `Task`)
- Call ScheduleWakeup with the `/dev` prompt and reason `"verify wait: <step>"`
- On each wake: poll `BashOutput`, decide continue vs exit
- On completion: proceed to P9; on fail: return to P7 with evidence

## P9: SHIP

| Task Type | Steps |
|-----------|-------|
| **DEVELOP** | 1. `/codex-review` (Codex + 5 Claude agents + Haiku cross-scorer — supersedes `requesting-code-review`) → fix Critical/Important. 2. STANDARD+: `security-reviewer` agent for auth/crypto/input code. 3. `verify-dev.sh` final gate. 4. `finishing-a-development-branch` → PR. 5. Push (ask user). 6. DEEP: enter LOOP Pattern 1 (CI wait) via ScheduleWakeup — NOT blocking `gh run watch`. |
| **RESEARCH** | 1. Self-review report for accuracy. 2. Deliver: report + claudemem notes. 3. Present Goal/Done/Next summary. |
| **CICD** | 1. Apply change (with user confirmation). 2. Monitor via LOOP Pattern 1 or health check. 3. Verify health. 4. Document in runbook if new pattern. |

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
| `--loop` | **Redundant on STANDARD/DEEP — loop is auto-enabled by default** (see CONTINUITY CONTRACT). Kept for explicit clarity. |
| `--no-loop` | Force blocking mode even on STANDARD/DEEP (use when you want to watch a long wait live rather than auto-loop) |
| `--max-loop-iter=N` | Cap max wakes per loop pattern (default 20 for CI, 15 for long-task, 10 for agent-merge) |
| `--loop-delay=N` | Default delay seconds for loop cycles (default 270 — stays within prompt cache TTL) |

---

## LOOP INTEGRATION (ScheduleWakeup)

**`ScheduleWakeup` is a Claude Code harness built-in tool** (not a skill, not a
plugin — provided by the CLI runtime itself). It re-fires the same `/loop`
prompt after N seconds so a single session can "check back" on long-running
work without blocking. Used inside /dev for phases that wait on external
signals (CI, long builds, agent teams, deployments).

### Core Contract

```
ScheduleWakeup(
  delaySeconds: int,     # clamped to [60, 3600] by the runtime
  prompt: str,           # MUST be the same /dev input — forwards the loop
  reason: str            # short specific line shown to user between wakes
)
```

Omit the call to end the loop. For an autonomous /loop (no user prompt),
pass the literal sentinel `<<autonomous-loop-dynamic>>` as `prompt` instead
(do NOT confuse with `<<autonomous-loop>>` which is the CronCreate variant).

### When /dev SHOULD use it — AUTO by default on STANDARD/DEEP

Per CONTINUITY CONTRACT, loop is **automatically engaged** in these phases
when the relevant signal exists. User does NOT need to invoke it manually:

| Phase | Pattern | Signal to watch | Auto-trigger condition | Decision |
|-------|---------|-----------------|----------------------|----------|
| P7 EXECUTE (DEEP) | Agent-merge loop | `TaskList --status running == 0` | 3+ parallel subagents dispatched | All agents done → continue |
| P7 EXECUTE | Long-build loop | `BashOutput` of background task | Build cmd started with `run_in_background=true` and expected >2 min | Build complete → continue; fail → P7 retry |
| P8 VERIFY | Long-verify loop | Full suite / e2e / docker build | `/verify` step elapsed >2 min | Pass → P9; Fail → P7 with evidence |
| P9 SHIP (DEEP) | CI-wait loop | `gh pr checks <pr#>` | PR pushed AND at least one check is pending | Green → P10; Red → auto-fix subtask → restart |
| P9 SHIP CICD | Deploy-health loop | `curl /health` or `gh run watch` status | Deploy applied AND health probe defined | Healthy → runbook; Unhealthy → rollback |

**Auto vs manual**: `--no-loop` disables all of the above (blocking mode).
`--loop` is redundant (already the default). `--max-loop-iter` and
`--loop-delay` tune individual patterns.

### When /dev MUST NOT use it

- QUICK tier — no phase is long enough to justify cache cycling
- P3 BRAINSTORM / P5 PLAN — pure reasoning, no external signal
- CHECKPOINT 1 / CHECKPOINT 2 — human decision; session auto-pauses on AskUserQuestion
- Any phase completing in <60s (below delay floor, overhead not worth it)

### Cost Budget — prompt cache TTL trap

Anthropic prompt cache TTL = **300 seconds**. This gives the regimes:

| delaySeconds | Regime | Economics | Use for |
|------|--------|-----------|---------|
| 60–270 | cache-HIT | near-free per wake (incremental context only) | Active polling: CI pending, build mid-flight, recent test run |
| **300** | WORST | full context reread without amortization | **NEVER — do not pick 300** |
| 301–3600 | cache-MISS | 1 full-context reread per wake | Genuinely idle waits: overnight deploy, slow-queue jobs |

Default for /dev loops: **270s** (last cache-safe value). Use `--loop-delay=N`
to override. Only go above 300s if each wake is expected to find "still
waiting, nothing new" — otherwise cache-HIT cadence is strictly cheaper.

### Exit Conditions Matrix (MANDATORY — declare before each loop)

Before the FIRST `ScheduleWakeup` call of a loop, output this block inline:

```
┌─ LOOP CONFIG: <pattern-name> ─────────────────
│ Phase: P<N>  |  Pattern: <1-CI | 2-long-task | 3-agent-merge | 4-deploy-health>
│ Success exit: <precise signal, e.g., "gh pr checks #1234 all green">
│ Failure exit: <precise signal, e.g., "any check = fail">
│ Timeout exit: <iter >= max OR elapsed > Xm>
│ Delay: <s>s  |  Max iter: <N>  |  Cost cap: ~<N> full-context reads
└────────────────────────────────────────────────
```

At least one of (success, failure, timeout) MUST fire within max_iter. If you
can't state a concrete signal → don't start the loop (use blocking call instead).

### Standard Patterns

#### Pattern 1 — CI Wait (P9 DEEP, DEVELOP + CICD)
```
Trigger     : PR pushed via finishing-a-development-branch
Signal      : gh pr checks <pr#> → pass | pending | fail
Delay       : 270s while pending
Max iter    : 20 (≈ 90 min — covers most CI runs)
Success     : all checks green → proceed to P10 ARCHIVE
Failure     : any check red → spawn fix subtask (new P7 cycle), re-push, restart loop iter counter
Timeout     : escalate to user ("CI stuck > 90min, investigating")
reason field: "CI wait iter <k>/20 — PR #<n> checks pending"
```

#### Pattern 2 — Long Task (P7, P8)
```
Trigger     : Background build/test started (run_in_background=true or Task)
Signal      : BashOutput status + exit code
Delay       : 120s for first 5 min, 270s after (adaptive — cache still hits in both)
Max iter    : 15 (≈ 60 min)
Success     : exit code 0 → proceed
Failure     : exit code non-zero → extract last 30 lines of log, return to P7 with evidence
Timeout     : kill background task, report partial output, escalate
reason field: "build wait iter <k>/15 — <command> elapsed <m>m"
```

#### Pattern 3 — Agent Merge (P7 DEEP with Agent Teams)
```
Trigger     : 3+ parallel subagents dispatched via dispatching-parallel-agents
Signal      : TaskList where status == "running" → 0
Delay       : 180s
Max iter    : 10 (≈ 30 min)
Success     : all agents completed → gather TaskOutput, synthesize, continue
Failure     : any agent errored → inspect error, decide retry vs abort
Timeout     : kill hanging agents, proceed with partial results + flag
reason field: "agent merge iter <k>/10 — <N> agents running, <M> done"
```

#### Pattern 4 — Deploy Health (P9 CICD)
```
Trigger     : Deploy applied (k8s rollout, docker compose up, terraform apply)
Signal      : curl health endpoint OR gh run status OR platform-specific probe
Delay       : 60s for first 3 min (rapid smoke), 270s after
Max iter    : 15
Success     : 5 consecutive green health checks → runbook entry + P10
Failure     : any 5xx or status!=healthy for 3 consecutive checks → auto-rollback trigger, return to P7
Timeout     : declare degraded state, escalate
reason field: "deploy health iter <k>/15 — <service> status=<state>"
```

### Call Template

```
ScheduleWakeup(
  delaySeconds=270,
  prompt="<exact original /dev input — e.g., '/dev add OAuth2 login'>",
  reason="CI wait iter 3/20 — PR #1234 checks pending (typescript, python, e2e)"
)
```

- `prompt` must be verbatim the original /dev invocation. Stripping or
  rephrasing loses /dev's context-classification.
- `reason` is user-facing — it's the ONLY line shown between wakes — so it
  must tell them specifically what is being watched and where in the loop.

### Anti-Patterns (forbidden inside /dev)

| Anti-pattern | Why forbidden |
|--------------|---------------|
| Calling ScheduleWakeup without declaring exit conditions | No way to prove the loop terminates — risks cost drift |
| Picking `delaySeconds=300` | Worst-of-both: cache miss + no idle benefit |
| Loop without max_iter cap | Prompt/signal drift can cause infinite cycling |
| Using same loop across two phases | Each wake reruns P0-P2, wastes context; split instead |
| Omitting reason field or making it generic ("continue loop") | User has zero visibility into what /dev is doing |
| Re-entering a loop pattern after `exit-failure` without root-cause fix | Cycling the same error burns cache without progress |

### Loop Interaction with CHECKPOINTs

- CHECKPOINT 1 (after P5) and CHECKPOINT 2 (after P9) use `AskUserQuestion` — the
  session pauses for the human. **Do NOT call ScheduleWakeup at checkpoints** —
  it races against human response.
- If a loop is active when a checkpoint fires, end the loop first (declare
  `exit-success` or `exit-escalate`), then present the checkpoint.

---

## ECC (everything-claude-code) INTEGRATION

ECC plugin provides language-specific agents, hooks, and skills that enhance /dev phases.

### Auto-Active (no action needed — hooks run via plugin)
- **PostToolUse**: quality-gate, build-analysis, console-log-warning, typecheck
- **PreToolUse**: commit-quality, config-protection, block-no-verify, observe (CL v2)
- **Stop**: cost-tracker, session-persist, evaluate-session (pattern extraction)
- **PreCompact**: save state before compaction

### Language-Aware Agent Selection (P7/P9)
Detect project language in P1 (via indicator files). Use corresponding ECC agents:
- `tdd-guide`: Enhanced TDD enforcement (replaces generic TDD when available)
- `{lang}-reviewer`: Language-specific code review (typescript, python, go, rust, java, kotlin, cpp, flutter)
- `{lang}-build-resolver`: Language-specific build error resolution
- `database-reviewer`: SQL/ORM change review (any project with DB operations)
- `security-reviewer`: Security-focused review (auth, crypto, input handling)
- `architect`: Architecture review and ADR generation (DEEP tier P3)

### ECC Hook Profile
Controlled via `ECC_HOOK_PROFILE` env var:
- `minimal`: lifecycle hooks only (session-start, session-end)
- `standard` (default): + quality gates, observers, commit checks
- `strict`: + auto-format, typecheck, full security monitoring
