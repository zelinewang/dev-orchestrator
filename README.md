# /dev — AI Development Orchestrator

**One command. Any task. 4-layer enforcement.**

`/dev` turns Claude Code into an end-to-end development workflow — for code, research, and infrastructure tasks. Describe what you want → the orchestrator investigates, plans, executes, verifies, and ships. Zero mandatory human checkpoints. Deterministic hooks enforce quality gates automatically.

```
You:   /dev "add user authentication with JWT and refresh tokens"

AI:    ┌─ INVESTIGATE ───────────────────────────
       │ Status: DONE | Sources: memory, code, docs, git
       │ Next: PLAN
       └─────────────────────────────────────────

       ┌─ PLAN ─────────────────────────────────
       │ Intent: build | Depth: deep
       │ 8 subtasks, TDD per each
       │ Next: EXECUTE
       └─────────────────────────────────────────

       [TDD task 1/8 → ... → 8/8 ✓]
       [47/47 tests passing. 0 regressions.]

       ┌─ SHIP ─────────────────────────────────
       │ PR #142 created. CI green.
       │ Progress saved to dev-progress/feat-jwt-auth.json
       └─────────────────────────────────────────
```

## Architecture: 4-Layer Enforcement

Designed from 19 primary research sources (Anthropic, OpenAI, Stripe, arXiv, Martin Fowler, Mitchell Hashimoto). Core insight: **deterministic infrastructure > prompt-level guidance**.

```
┌─────────────────────────────────────────────────────┐
│  Layer 4: File-Backed State (survives everything)    │
│  .claude/dev-progress/<branch>.json                  │
├─────────────────────────────────────────────────────┤
│  Layer 3: Hooks (100% deterministic, zero context)   │
│  SessionStart → inject progress                      │
│  PreToolUse → verify-on-commit gate                  │
│  PostToolUse → auto-lint Python                      │
│  Stop → persist state                                │
├─────────────────────────────────────────────────────┤
│  Layer 2: Rules + CLAUDE.md (~80%, compact-safe)     │
│  phases.md, deep-investigation.md, tdd-protocol.md   │
│  wrapup-retrospective.md                             │
├─────────────────────────────────────────────────────┤
│  Layer 1: /dev Skill (on-demand, full guidance)      │
│  739 lines — only loaded when /dev is invoked        │
└─────────────────────────────────────────────────────┘
```

| Layer | Compliance | Survives compact? | Context cost |
|-------|-----------|-------------------|-------------|
| Hooks | **100%** (deterministic) | ✅ always active | Zero |
| Rules + CLAUDE.md | **~80%** (probabilistic) | ✅ re-injected | ~900 tokens |
| /dev Skill | **~70%** (probabilistic) | ❌ ephemeral | ~3,000 tokens (on-demand) |

## Version History

| Version | Key Change | Enforcement |
|---------|-----------|-------------|
| v1.0 | Core orchestrator, 3 tiers | Text suggestions (AI can skip) |
| v2.0 | TDD Protocol + verify-dev.sh | Mandatory status blocks |
| v2.1 | Task routing (DEVELOP/RESEARCH/CICD) | Phase status blocks (16% compliance measured) |
| v3.0 | Zero-checkpoint continuity contract | AI self-enforces (aspirational) |
| **v4.0** | **4-layer harness architecture** | **Hooks (100%) + Rules (80%) + Skill (on-demand)** |

## How It Works

### Intent Routing (from ReSpecV philosophy)

Route by intent, not file count:

| Intent | When | Workflow |
|--------|------|---------|
| **Build** | New feature, architecture | Full: investigate → plan → execute → verify → ship |
| **Fix** | Bug, hotfix, incident | Evidence-first: logs → root-cause → TDD fix → verify |
| **Research** | Investigate, analyze, learn | Investigate → notes → report (no TDD/worktree) |
| **Deploy** | Pipeline, infra, config | Impact + rollback strategy → dry-run → apply → monitor |
| **Trivial** | Typo, comment, config | Skip to execute |

### Core Phases

1. **Investigate** — Search claudemem, read code, check docs (context7), read git log. For bugs: **check production logs FIRST**.
2. **Plan** — State intent + success criteria + affected files in one status block.
3. **Execute** — TDD per subtask: RED → GREEN → VERIFY → COMMIT. Language-aware reviewers.
4. **Verify** — Auto-enforced by pre-commit hook (`exit 2` if verify-dev.sh fails). Manual: `/verify`.
5. **Ship** — Push feature branch, create PR, update `dev-progress/<branch>.json`.

### Deep Mode (`--deep`)

Adds: agent teams for parallel subtasks, ScheduleWakeup for CI wait (4 patterns: CI-wait, long-build, agent-merge, deploy-health), language-aware ECC reviewers, OpenSpec integration.

## Hooks (Deterministic Enforcement)

All hooks run on the host machine at zero context cost. They fire automatically — no invocation needed.

### `dev-verify-on-commit.sh` (PreToolUse:Bash)
**Two-tier gate on every `git commit`:**
- `verify-dev.sh` failure → `exit 2` (hard block — cannot be auto-accepted)
- `ruff` lint issues → `additionalContext` warning (visible but non-blocking)

### `dev-quality-gate.sh` (PostToolUse:Edit|Write)
Auto-formats Python files with `ruff format --quiet` after every edit. Non-blocking.
Production validated: 3/3 correct triggers, zero false positives.

### `dev-session-start.sh` (SessionStart)
Reads branch-scoped `dev-progress/<branch>.json` and injects task state via `additionalContext`. Enables cross-session resume. Skips if no active task (>24h stale).

### `dev-session-end.sh` (Stop)
Updates `updated_at` timestamp in progress file for continuity.

## Rules (Compact-Safe Guidance)

Rules files in `~/.claude/rules/dev-workflow/` are loaded at every session start and survive context compaction. ~80% compliance (probabilistic but durable).

| File | Purpose | Lines |
|------|---------|-------|
| `phases.md` | 5 phases, intent routing, status blocks, escalation | 35 |
| `deep-investigation.md` | Logs-first for bugs, counter-hypothesis check | 34 |
| `tdd-protocol.md` | VERIFY+COMMIT steps, when-to-apply by intent | 16 |
| `wrapup-retrospective.md` | 6-dimension session retrospective template | 43 |

## Cross-Session State

Branch-scoped JSON progress files at `.claude/dev-progress/<branch>.json`:

```json
{
  "task": "Add JWT authentication",
  "intent": "build",
  "phase": "execute",
  "subtasks": [
    {"name": "Create auth middleware", "status": "done"},
    {"name": "Add token refresh", "status": "in_progress"}
  ]
}
```

Helper script: `dev-progress-update.sh create|phase|subtask-done|subtask-add|done`

## Wrapup Retrospective

Every `/wrapup` includes a mandatory Phase 3.5 evaluating 6 dimensions:
- **A.** Phase compliance (did I follow the workflow?)
- **B.** Investigation quality (did I explore enough context?)
- **C.** User corrections (count + root cause)
- **D.** Tool utilization (used vs should-have-used)
- **E.** Hook effectiveness (trigger table)
- **F.** Workflow design feedback (design problem vs execution problem)

This turns every session into a test session for the dev workflow itself.

## Installation

### Option A: Via claude-code-config (recommended for existing users)

```bash
cd ~/claude-code-config && git pull
# Hooks, rules, and scripts are in global/
# Run install.sh to sync to ~/.claude/
bash install.sh
```

### Option B: Manual Install

```bash
# Hooks (user-level, register in ~/.claude/settings.json)
cp hooks/dev-*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/dev-*.sh

# Rules
mkdir -p ~/.claude/rules/dev-workflow
cp rules/dev-workflow/*.md ~/.claude/rules/dev-workflow/

# Scripts
cp scripts/dev-progress-update.sh ~/.claude/scripts/
cp scripts/verify-dev.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/dev-*.sh ~/.claude/scripts/verify-dev.sh

# Skill
mkdir -p ~/.claude/skills/dev-orchestrator
cp skills/dev-orchestrator/SKILL.md ~/.claude/skills/dev-orchestrator/

# Command
cp commands/dev.md ~/.claude/commands/

# Register hooks in ~/.claude/settings.json (see hooks/ for JSON config)
```

### Requirements

- [Claude Code](https://claude.ai/claude-code) (Opus 4.6 or 4.7)
- `ruff` installed on host (`pip install ruff`) — for quality-gate hook
- [superpowers](https://github.com/obra/superpowers) plugin — TDD, debugging, planning skills
- [claudemem](https://github.com/zelinewang/claudemem) — cross-session memory (recommended)

## Usage

```bash
/dev "add dark mode with system preference detection"
/dev --deep "redesign payment processing pipeline"
/dev "fix the 500 error in video upload endpoint"
/dev "investigate how our auth system handles token rotation"
```

The orchestrator auto-detects intent and depth. Use `--deep` to force agent teams and ScheduleWakeup loops.

## Design Principles

1. **Deterministic enforcement > prompt guidance** (Microsoft AGT: 0% violation vs 27%)
2. **Progressive enforcement**: observe → measure → selectively enforce (ARMO)
3. **Design for obsolescence**: every hook has an explicit "when to remove" condition
4. **Feedforward + feedback**: rules guide behavior, hooks catch mistakes (Martin Fowler)
5. **File-backed state > in-context state**: JSON progress files survive everything

## Research Basis

v4 was designed from 19 primary sources:
- Anthropic: 4 engineering blogs (harnesses, managed agents, long-running apps, hook spec)
- OpenAI: harness engineering blog
- Academic: 5 arXiv papers (Dive into Claude Code, NLAH, Inside the Scaffold, VeRO, OpenDev)
- Industry: Stripe Minions (1,000+ PRs/week), Herashchenko, Sourcegraph, Vercel
- Experts: Hashimoto (coined "harness engineering"), Willison, Fowler
- Governance: Microsoft AGT (0% violation), EU AI Act, NIST, Singapore IMDA

## Roadmap

- [x] v1.0 — Core orchestrator, 3 tiers, 7 verification rules
- [x] v2.0 — TDD Protocol + verify-dev.sh enforcement
- [x] v2.1 — Task routing (DEVELOP/RESEARCH/CICD) + status blocks
- [x] v3.0 — Zero-checkpoint continuity contract + ScheduleWakeup loops
- [x] **v4.0 — 4-layer harness architecture (hooks + rules + state + skill)**
- [ ] v4.1 — Compliance measurement baseline (skill-comply)
- [ ] v4.2 — Instruction fade-out countermeasure (periodic additionalContext)
- [ ] v4.3 — /dev skill ↔ dev-progress.json deep integration
- [ ] v5.0 — Adaptive harness (progressive obsolescence as models improve)

## License

MIT
