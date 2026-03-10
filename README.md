# /dev — AI Development Orchestrator

**One command. Any task type. Self-enforcing.**

`/dev` turns your AI coding agent into a complete development team — for code, research, and infrastructure tasks. Describe what you want in natural language — the orchestrator classifies, investigates, plans, executes, verifies, and delivers. You review twice: the plan and the deliverable. Everything else is automated and enforced.

```
You:   /dev "add user authentication with JWT and refresh tokens"

AI:    ┌─ P1: INVESTIGATE ───────────────────────
       │ Status: DONE | Sources: 5 (memory, code, specs, git, web)
       │ Next: P2 CLASSIFY
       └─────────────────────────────────────────

       ┌─ P2: CLASSIFY ─────────────────────────
       │ Status: DONE
       │ Task: DEVELOP | Tier: STANDARD
       │ Next: P3 BRAINSTORM
       └─────────────────────────────────────────

       [Brainstorm → Specs → Plan...]

       🛑 CHECKPOINT 1: Review specs? [looks good]

You:   looks good

AI:    [Worktree → TDD task 1/12 → ... → 12/12 ✓]
       [47/47 tests passing. 0 regressions.]
       [PR #142 created]

       🛑 CHECKPOINT 2: Review PR?

You:   approved
AI:    ✓ Specs archived. Memory saved. Done.
```

## What's New in v2

v2 was born from a self-audit that revealed **16% protocol compliance** in a real session. The protocol was well-designed but not self-enforcing — the AI could silently skip phases without consequence.

### Key Changes

| Feature | v1 | v2 |
|---------|----|----|
| **Task Types** | Code only | DEVELOP + RESEARCH + CICD |
| **Enforcement** | Text suggestions | Mandatory phase status blocks |
| **Phase Skipping** | Silent (no trace) | SKIP requires documented reason |
| **Brainstorming** | "Pre-Phase 1" (skippable) | P3: MANDATORY |
| **Phase Naming** | Confusing (Pre-Phase 1, Phase 0) | Clean P0-P10 |
| **Plan Mode** | Conflicting workflows | /dev takes priority |
| **Verification** | Code tests only | +research coverage +CICD secrets scan |
| **Override Flags** | 4 (--quick/deep/no-spec/no-pr) | 6 (+--research/--cicd) |

## Problem

AI coding today is "vibe coding" — you chat, the AI writes code, but:

- **Requirements scatter** across chat history and disappear when context fills up
- **No verification discipline** — AI says "done" but tests aren't actually passing
- **Regression blindness** — fixing one thing silently breaks another
- **Tool overload** — 40+ skills/tools available, but you must remember which to invoke when
- **Cross-session amnesia** — start a new chat, lose all context from the previous one
- **Non-code tasks unsupported** — research, CICD, and documentation tasks forced into code workflow

## Solution

`/dev` is a meta-orchestrator that chains your existing tools into an end-to-end pipeline with structural enforcement. It doesn't replace your tools — it conducts them like an orchestra.

```
Developer: /dev "description"
    │
    ▼
┌── P1: INVESTIGATE (5 min, read-only) ───────────────────────┐
│   Search memory → Read code → Check specs → Web research     │
│   → Evidence-based classification + tier recommendation      │
└────────────┬────────────────────┬───────────────────────────┘
             │                    │
    ┌────────▼─────────┐  ┌─────▼─────────────────────────────┐
    │ P2: CLASSIFY      │  │ Task Types                         │
    │ DEVELOP/RESEARCH  │  │ ┌─ DEVELOP: Full TDD + PR          │
    │ /CICD + Tier      │  │ ├─ RESEARCH: Investigate + report  │
    │                   │  │ └─ CICD: Dry-run + rollback verify │
    └────────┬─────────┘  └───────────────────────────────────┘
             │
    ┌────────▼────────────────────────────────┐
    │ QUICK          STANDARD / DEEP           │
    │                                          │
    │ Root cause     1. Brainstorm (mandatory)  │
    │ → TDD fix      2. Specs / proposal        │
    │ → Verify       3. Plan → you review       │
    │ → Commit       4. Setup (worktree/clone)  │
    │ → Memory       5. Execute (TDD/research)  │
    │                6. Double-verify            │
    │                7. Ship → you review        │
    │                8. Archive + memory         │
    └─────────────────────────────────────────┘
```

### Three Task Types (Auto-Classified)

| Type | When | Key Differences |
|------|------|----------------|
| **DEVELOP** | Code change needed (feature, bug, refactor) | Full TDD + worktree + PR |
| **RESEARCH** | Investigate, document, analyze, learn | No TDD/worktree, keep brainstorm/verify/wrapup |
| **CICD** | Pipeline, infra, deploy, config change | No TDD, add dry-run + rollback verification |

### Three Tiers (Auto-Detected)

| Tier | When | What Happens | Time |
|------|------|--------------|------|
| **QUICK** | Bug fix, small change | Root cause → TDD fix → verify → commit | 5-15 min |
| **STANDARD** | New feature, behavior change | Full P0-P10 phases, all gates | 30-120 min |
| **DEEP** | Architecture, multi-module, unclear root cause | Full phases + Agent Teams + CI wait + /wrapup | 2-8 hrs |

**Detection is investigation-based, not keyword-based.** The orchestrator spends 5 minutes reading your codebase before deciding.

## Self-Enforcement

Every phase outputs a mandatory status block — no silent skipping allowed:

```
┌─ P<N>: <NAME> ────────────────────────────────
│ Status: DONE | SKIP <reason> | ADAPT <explanation>
│ Task: <type> | Tier: <tier>
│ Key actions: <what was done>
│ Next: P<N+1>
└────────────────────────────────────────────────
```

This is the core innovation of v2: phases are structurally visible, not silently skippable.

## 7 Verification Rules

Built into every phase, so you never need to remind the AI:

1. **Double-Verify** — Every "done" backed by fresh evidence with counts
2. **Audit-Driven** — Test fails? Check if the test is wrong first
3. **Root Cause** — Don't patch symptoms. Find the design-level issue
4. **Regression Paranoia** — Full test suite after EVERY change
5. **CICD Awareness** — "Done" = passes locally AND CI passes
6. **Closed-Loop** — Every cycle closes its own loop
7. **Cross-Session** — Search memory before starting, save knowledge after

## Requirements

### Required

- [Claude Code](https://claude.ai/claude-code) v1.0.33+
- [superpowers](https://github.com/obra/superpowers) plugin — TDD, debugging, planning, verification, git workflows

### Recommended

- [OpenSpec](https://github.com/Fission-AI/OpenSpec) v1.2.0+ — spec-driven development (`npm install -g @fission-ai/openspec@latest`)
- [feature-dev](https://github.com/anthropics/claude-code-plugins) plugin — code-explorer, code-architect, code-reviewer agents
- [claudemem](https://github.com/zelinewang/claudemem) — cross-session persistent memory
- [commit-commands](https://github.com/anthropics/claude-code-plugins) plugin — git commit/push/PR workflows

### Optional

- Agent Teams experimental feature (for DEEP tier competing hypothesis debugging)

## Installation

### Option A: Plugin Install (recommended)

```bash
# From GitHub (when published)
claude plugins install dev-orchestrator

# Or from local directory
claude --plugin-dir /path/to/dev-orchestrator
```

### Option B: Manual Install

```bash
# Copy skill + scripts
mkdir -p ~/.claude/skills/dev-orchestrator ~/.claude/scripts
cp skills/dev-orchestrator/SKILL.md ~/.claude/skills/dev-orchestrator/
cp scripts/verify-dev.sh ~/.claude/scripts/
chmod +x ~/.claude/scripts/verify-dev.sh

# Copy command
cp commands/dev.md ~/.claude/commands/

# Optional: Enable Agent Teams
# Add to ~/.claude/settings.json under "env":
#   "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

Restart Claude Code to load the new skill.

### Option C: Per-Project Install

```bash
cd your-project
mkdir -p .claude/skills/dev-orchestrator .claude/scripts
cp skills/dev-orchestrator/SKILL.md .claude/skills/dev-orchestrator/
cp scripts/verify-dev.sh .claude/scripts/
cp commands/dev.md .claude/commands/
```

## Usage

### Any Development Task

```
/dev "add dark mode with system preference detection"
```

### Research Tasks

```
/dev --research "investigate how our auth system handles token rotation"
```

### CICD Tasks

```
/dev --cicd "add staging environment to GitHub Actions pipeline"
```

### Override Tier

```
/dev --quick "fix typo in error message"
/dev --deep "redesign payment processing pipeline"
```

### Skip Specs or PR

```
/dev --no-spec "refactor auth module to reduce duplication"
/dev --no-pr "fix CSS alignment on login page"
```

## How It Works

### Phase-by-Phase (all task types share the same structure)

| Phase | DEVELOP | RESEARCH | CICD |
|-------|---------|----------|------|
| **P0 PRE-CHECK** | Git + OpenSpec + CLAUDE.md | Git warn only | Git + CI config |
| **P1 INVESTIGATE** | Memory + code + docs | Memory + web + repo | Memory + pipeline |
| **P2 CLASSIFY** | → DEVELOP | → RESEARCH | → CICD |
| **P3 BRAINSTORM** | Intent + design trade-offs | Deliverable scope | Impact + rollback |
| **P4 SPECIFY** | OpenSpec specs | Research proposal | Change spec |
| **P5 PLAN** | TDD tasks (2-5 min each) | Questions + sources | Steps + dry-run |
| **P6 SETUP** | Git worktree + baseline | Clone repo if needed | Backup config |
| **P7 EXECUTE** | TDD per task + subagents | Investigate + notes | Implement + dry-run |
| **P8 VERIFY** | Test suite + verify-dev.sh | Coverage check | Infra + rollback test |
| **P9 SHIP** | Code review + PR | Deliver report + notes | Apply + monitor |
| **P10 ARCHIVE** | OpenSpec archive + memory | claudemem + /wrapup | Notes + runbook |

### Verification Script

Automated gate that blocks bad deliveries:

```bash
# For code tasks
bash ~/.claude/scripts/verify-dev.sh

# For research tasks
bash ~/.claude/scripts/verify-dev.sh --research "search-term" /path/to/report.md

# For CICD tasks (checks for leaked secrets)
bash ~/.claude/scripts/verify-dev.sh --cicd
```

## Customization

### Adapt to Your Stack

The orchestrator reads your project's `openspec/config.yaml` for context:

```yaml
schema: spec-driven
context: |
  Tech stack: Python, FastAPI, PostgreSQL
  Testing: pytest + httpx
  Style: async by default
rules:
  specs:
    - Use Given/When/Then format
  tasks:
    - Each task < 5 minutes
```

### Adapt to Your Workflow

The skill works by invoking other skills by name. Edit the SKILL.md to reference your preferred tools.

## Roadmap

- [x] v0.1.0 — Core orchestrator with 3 tiers + 7 rules
- [x] v2.0.0 — TDD Protocol + verify-dev.sh enforcement
- [x] **v2.1.0 — Task routing (DEVELOP/RESEARCH/CICD) + phase status blocks + self-enforcement**
- [ ] v2.2.0 — Compliance checklist (if status blocks prove insufficient)
- [ ] v3.0.0 — Cursor/Windsurf cross-tool support
- [ ] v4.0.0 — Stable API, submitted to Anthropic marketplace

## License

MIT
