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
UNDERSTAND ──[GATE]──> BUILD ──[GATE]──> DELIVER ───>
P0-P5   (1 optional clarify)   P6-P7    P8-P10 (full auto)
Zero mandatory checkpoints — see CONTINUITY CONTRACT
```

---

## CONTINUITY CONTRACT (zero-checkpoint, full-auto) — v3

**Once /dev starts, it owns the task from P0 to P10 ARCHIVE. Zero mandatory
checkpoints.** /dev is modelling a senior engineer's end-to-end workflow: they
don't stop every 15 minutes to ask "should I continue?". They stop only when
something genuinely demands human input.

### Design evolution (claudemem note 271c6900, 2026-03-08)

| Version | Checkpoints | Philosophy |
|---------|------------|-----------|
| v0.1 | 2 (Spec + PR) | Conservative: human gates at intent + delivery |
| v0.3 | 1 (Spec only) | PR Review redundant after TDD + verify + regression |
| v0.5 | confidence-based | Auto-approve when AI confidence high |
| **v3 (current)** | **0 mandatory** | **Full auto, interrupt ONLY on genuine anomaly** |

### Three legitimate pauses (ONLY these — nothing else)

1. **REQUIREMENT CLARIFICATION** (at start of P3 BRAINSTORM, one-shot)
   Fires ONLY when the user's requirement has load-bearing ambiguity that AI
   cannot resolve via claudemem + codebase + web + DAO reasoning. See the
   "Requirement Clarification Gate" section below for the test.
   If requirement is specific enough → skip entirely, no pause.

2. **EXTERNAL WAIT** (during P7/P8/P9)
   CI / long build / agent teams / deploy health — enters a LOOP pattern via
   `ScheduleWakeup`, resumes automatically on signal. This is not really a
   "pause for human" — it's cached dormancy with automatic resume.

3. **ANOMALY ESCALATION** (anywhere)
   AI encounters a decision it cannot make with confidence ≥70% after using
   all available resources (claudemem, codebase, web, DAO, evidence). Covers:
   - Hard red-line trigger (secret about to be committed, destructive DB op,
     .env modification, deny-listed command)
   - Rules-conflict with no override precedent (e.g., user instruction says X,
     CLAUDE.md says not-X, and context cannot arbitrate)
   - Loop `exit-escalate` verdict from any Pattern 1-4

Any other "stop and ask" = **protocol violation**. Examples of forbidden stops:
- "P3 BRAINSTORM done — approve to proceed?" ❌
- "Plan created — should I start?" ❌
- "PR ready — want me to push?" ❌ (just push; user reviews in git log / GitHub)
- "Verify passed — archive now?" ❌
- "I'm not sure whether to X or Y, which do you want?" ❌ (use DAO + evidence;
  only escalate if genuinely >30% probability of being wrong)

### Requirement Clarification Gate (P3 prefix, at most once per /dev invocation)

**Test — do I need to clarify?** Answer these before P3 BRAINSTORM:

1. Can I name the target file(s) / module(s) from the user's words + P1 findings?
2. Can I name the success criterion in one concrete sentence (e.g., "function
   X returns Y when Z", not "make it better")?
3. Do I have ≥70% confidence on the implementation approach from DAO +
   codebase patterns + claudemem?

If all three are YES → proceed to P3, no pause.
If any is NO → ONE `AskUserQuestion` with 2-4 pointed options to resolve the
specific ambiguity. Phrase it like a senior engineer: "I see three ways this
could be interpreted — A, B, C. Which did you have in mind?"

**Calibration examples**:

| User said | Decision |
|-----------|----------|
| "fix the 500 in the video upload endpoint" | Specific → skip gate |
| "add refresh-token support to JWT auth per auth0 pattern" | Specific → skip gate |
| "make the pipeline faster" | Ambiguous: which pipeline? how fast? → ask |
| "add auth" | Ambiguous: OAuth2 vs JWT vs session? → ask |
| "refactor this mess" (with file in context) | Ambiguous: what mess? preserve API? → ask |
| "add tests for the user service" | Specific → skip gate (AI can pick TDD patterns from repo) |

### Auto-Loop Default (STANDARD and DEEP tiers)

- **STANDARD / DEEP**: Loop is **automatically enabled** for every phase that
  has an "external wait" signal. User does NOT need to pass `--loop`.
- **QUICK**: Loop is **automatically disabled** — every QUICK-tier work is by
  definition short enough to block on without cache cost.
- **Override**: `--no-loop` forces blocking mode even on STANDARD/DEEP (e.g.,
  when user wants to watch CI live).

### End-to-End Sequencing Examples (v3 zero-checkpoint)

**DEEP DEVELOP task with CI, requirement clear**:
```
P0 → P1 → P2 → P3 (requirement clear, skip clarify gate) → P4 → P5
  → P6 → P7 (TDD per task, Agent Teams may auto-loop at merge)
  → P8 (verify; if long-running → auto-loop Pattern 2)
  → P9 (push PR; auto-enter LOOP Pattern 1 for CI wait → green)
  → P10 ARCHIVE → DONE (session ends)
```
Zero stops unless loop-escalate or anomaly fires. User sees full /dev run in
one conversational turn (plus async wakes for CI).

**DEEP DEVELOP task with ambiguous requirement**:
```
P0 → P1 → P2 → [REQUIREMENT CLARIFICATION: 1 AskUserQuestion]
↓ (answered)
P3 → P4 → P5 → P6 → ... → P10 → DONE
```
One pause at the start — where clarification is highest-value — then full auto.

**QUICK task (bug fix)**:
```
P0 → P1 → P2 → [root cause] → TDD → verify → commit → DONE
```
Zero pauses. Ever.

### Why this matters

v3 removes the 5-10× user-cognitive-load penalty of v2 (which stopped at 2
checkpoints per task). A user running 5 /dev tasks in a day went from "10+
interruptions" to "0-2 interruptions" (one clarification if requirement is
ambiguous, zero otherwise). This frees the user to context-switch to other
work while /dev runs, matching how you'd delegate to a trusted senior engineer.

**Trade-off accepted**: if AI misjudges requirement clarity and proceeds
without asking, it may build the wrong thing and waste one cycle. This cost
is explicit and small vs. the cost of asking at every phase boundary. The
anomaly-escalation rule is the safety net for high-stakes misjudgments.

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
│ Elapsed: ~<iter × delay>m (estimated, not wall-clock)
│ Next delay: <s>s (expected-cache: hit if ≤270s, miss if >300s)
│ Signal: <pending|pass|fail|timeout|unknown>
│ Exit target: <success cond> | <fail cond>
│ Action this cycle: <what was done this wake>
│ Decision: <continue|exit-success|exit-failure|exit-escalate>
└────────────────────────────────────────────────
```

Fields Claude cannot directly observe (wall-clock across wakes, actual cache
hit/miss state) are marked as estimated/expected — derived from iter × delay.
Do NOT fabricate precise numbers; use the estimates.

If `iter >= max` or `cost cap hit` → Decision MUST be `exit-failure` or
`exit-escalate`. Do NOT silently continue past the declared cap.

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

Detection rules (evaluate in order — first match wins):

| Indicator (AND conditions) | Language | ECC Reviewer Agent | ECC Build Resolver |
|---------------|----------|-------------------|-------------------|
| `tsconfig.json` present | TypeScript | `typescript-reviewer` | `build-error-resolver` |
| `package.json` present AND `tsconfig.json` absent AND ≥1 `.ts`/`.tsx` file in project | TypeScript | `typescript-reviewer` | `build-error-resolver` |
| `package.json` present AND no `.ts`/`.tsx` files | JavaScript | `typescript-reviewer` (covers JS) | `build-error-resolver` |
| `pyproject.toml` / `setup.py` / `requirements.txt` | Python | `python-reviewer` | — |
| `go.mod` | Go | `go-reviewer` | `go-build-resolver` |
| `Cargo.toml` | Rust | `rust-reviewer` | `rust-build-resolver` |
| `build.gradle.kts` present | Kotlin | `kotlin-reviewer` | `kotlin-build-resolver` |
| `pom.xml` OR `build.gradle` (Groovy DSL, no `.kts`) | Java | `java-reviewer` | `java-build-resolver` |
| `CMakeLists.txt` / `*.cpp` | C++ | `cpp-reviewer` | `cpp-build-resolver` |
| `Package.swift` | Swift | — | — |
| `pubspec.yaml` | Flutter/Dart | `flutter-reviewer` | — |

Record detected language in P2 status block. If mixed-language, note primary + secondary.

Notes:
- `package.json` alone does NOT imply TypeScript — almost every JS project has it. Require `tsconfig.json` OR `.ts`/`.tsx` files as the disambiguator.
- `build.gradle.kts` is Kotlin DSL, overwhelmingly Kotlin projects. Java projects using Gradle typically use `build.gradle` (Groovy). Assigning `.kts` to Kotlin eliminates the previous Java/Kotlin collision.

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

<!-- CHECKPOINT 1 REMOVED in v3 zero-checkpoint model. Plan summary is written
to `docs/plans/YYYY-MM-DD-<name>.md` (DEVELOP) or equivalent artifact; user can
review in git diff or PR. If requirement was ambiguous, clarification already
happened at P3 prefix (Requirement Clarification Gate). No pause here. -->

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
| **DEVELOP** | 1. `/codex-review` (Codex + 5 Claude agents + Haiku cross-scorer — supersedes `requesting-code-review`) → fix Critical/Important. 2. STANDARD+: `security-reviewer` agent for auth/crypto/input code. 3. `verify-dev.sh` final gate. 4. `finishing-a-development-branch` → PR. 5. **Push automatically** (no confirmation — user reviews via git log / GitHub PR). Safety exception: if branch is `master` / `main` / `production`, anomaly-escalate to user. 6. DEEP: enter LOOP Pattern 1 (CI wait) via ScheduleWakeup — NOT blocking `gh run watch`. On CI green → proceed directly to P10. |
| **RESEARCH** | 1. Self-review report for accuracy. 2. Deliver: report + claudemem notes. 3. Present Goal/Done/Next summary. |
| **CICD** | 1. Apply change (anomaly-escalate to user only if change affects production infra; else proceed). 2. Monitor via LOOP Pattern 4 (Deploy Health) or blocking health check. 3. Verify health. 4. Document in runbook if new pattern. |

<!-- CHECKPOINT 2 REMOVED in v3 zero-checkpoint model. Deliverable summary is
still emitted as part of the P9 status block, but /dev proceeds directly to
P10 ARCHIVE without asking. User reviews via PR on GitHub, git log, or the
/wrapup report. If anomaly-escalation fires (see CONTINUITY CONTRACT), that's
the only reason to pause after P9. -->

**Deliverable summary** (emit as part of P9 status block, no pause):
- DEVELOP: "PR #<n> ready with X/X tests passing, 0 regressions."
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
5. /dev v3 has NO mandatory checkpoints — Plan Mode's own approval flow is the only pause after P5 if Plan Mode is active
6. Call ExitPlanMode after P5 (once Plan Mode approval received) to begin BUILD stage. Without Plan Mode, /dev proceeds directly from P5 to P6 (v3 zero-checkpoint default).

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

**Universal "unknown signal" circuit breaker** (applies to ALL patterns):
If the signal probe returns `unknown` for ≥3 consecutive wakes (e.g., network
errors, GitHub rate-limit, health endpoint timing out with no response),
emit `exit-escalate` immediately — do NOT keep polling until max_iter.
Rationale: sustained probe failure is an infrastructure problem, not the
thing the loop is waiting for. Let the user fix the infra.

### Standard Patterns

#### Pattern 1 — CI Wait (P9 DEEP, DEVELOP + CICD)
```
Trigger     : PR pushed via finishing-a-development-branch
Signal      : gh pr checks <pr#> → pass | pending | fail
Delay       : 270s while pending
Max iter    : 20 (≈ 90 min — covers most CI runs)
Max fix-cycles : 3 (outer cap across restarts; 4th CI failure → exit-escalate)
Success     : all checks green → exit-success → proceed to P10 ARCHIVE (no checkpoint)
Failure     : any check red → IF fix-cycles < 3: spawn fix subtask (new P7 cycle),
              re-push, restart iter counter, increment fix-cycle counter.
              ELSE: exit-escalate (3 fix cycles exhausted — likely flaky infra or real bug)
Timeout     : iter >= 20 with no signal change → exit-escalate
Unknown     : signal = unknown for ≥3 consecutive wakes (probe errors, network, rate limit) → exit-escalate
reason field: "CI wait iter <k>/20, fix-cycle <f>/3 — PR #<n> checks pending"
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

- v3 has NO mandatory CHECKPOINTs. The only pause points are (1) Requirement
  Clarification Gate at P3 prefix (one-shot, at session start) and (2) Anomaly
  Escalation (user-invoked by AI when decision confidence <70%). Neither happens
  mid-loop — clarification is before loops begin, anomaly is from inside a loop.
- **Do NOT call ScheduleWakeup while requesting human input via `AskUserQuestion`** —
  it races against human response. If an anomaly fires mid-loop, emit
  `exit-escalate` first, then raise `AskUserQuestion`.

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
