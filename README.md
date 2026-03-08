# /dev — AI Development Orchestrator

**One command. Full development lifecycle. Hands-free.**

`/dev` turns your AI coding agent into a complete development team. Describe what you want in natural language — the orchestrator investigates, plans, implements with TDD, verifies with regression protection, reviews, and ships a PR. You review twice: the specs and the PR. Everything else is automated.

```
You:   /dev "add user authentication with JWT and refresh tokens"

AI:    [5 min] Investigating codebase, memory, specs...
       → Recommending STANDARD tier (new feature, touches auth + API layers)

       [Creating specs...]
       ✓ proposal.md — JWT auth with refresh token rotation
       ✓ specs/auth/spec.md — 8 scenarios including token expiry, revocation
       ✓ design.md — 2 approaches evaluated, recommending middleware pattern
       ✓ tasks.md — 12 tasks, TDD, ~45 min estimated

       🛑 CHECKPOINT: Review specs? [looks good / add scenario / change approach]

You:   looks good

AI:    [Creating worktree, running baseline tests...]
       [Implementing task 1/12: TDD cycle...]
       [Spec review: ✓ | Quality review: ✓ | Regression: 0]
       [Implementing task 2/12...]
       ...
       [All 12 tasks complete. 47/47 tests passing. 0 regressions.]
       [PR created: #142 "Add JWT authentication with refresh tokens"]

       🛑 CHECKPOINT: Review PR?

You:   approved
AI:    ✓ Specs archived. Memory saved. Done.
```

## Problem

AI coding today is "vibe coding" — you chat, the AI writes code, but:

- **Requirements scatter** across chat history and disappear when context fills up
- **No verification discipline** — AI says "done" but tests aren't actually passing
- **Regression blindness** — fixing one thing silently breaks another
- **Tool overload** — 40+ skills/tools available, but you must remember which to invoke when
- **Cross-session amnesia** — start a new chat, lose all context from the previous one
- **Surface-level fixes** — AI patches symptoms instead of investigating root causes

## Solution

`/dev` is a meta-orchestrator that chains your existing tools into an end-to-end pipeline. It doesn't replace your tools — it conducts them like an orchestra.

```
Developer: /dev "description"
    │
    ▼
┌── INVESTIGATE (5 min, read-only) ──────────────────────────┐
│   Search memory → Read code → Check specs → Check git log  │
│   → Evidence-based tier recommendation                      │
└────────────┬──────────────────────┬────────────────────────┘
             │                      │
    ┌────────▼────────┐   ┌────────▼────────────────────────┐
    │ QUICK            │   │ STANDARD / DEEP                  │
    │                  │   │                                   │
    │ Root cause       │   │ 1. OpenSpec specs (→ you review) │
    │ → TDD fix        │   │ 2. TDD plan generation           │
    │ → Verify         │   │ 3. Isolated worktree             │
    │ → Auto-commit    │   │ 4. Subagent TDD + 2-stage review │
    │ → Save memory    │   │ 5. Double-verify + regression    │
    └──────────────────┘   │ 6. PR (→ you review)             │
                           │ 7. Archive specs + save memory   │
                           └───────────────────────────────────┘
```

### Three Tiers (Auto-Detected)

| Tier | When | What Happens | Time |
|------|------|--------------|------|
| **QUICK** | Bug fix, small change | Root cause investigation → TDD fix → verify → auto-commit | 5-15 min |
| **STANDARD** | New feature, behavior change | Specs → plan → worktree → multi-agent TDD → PR | 30-120 min |
| **DEEP** | Architecture change, CICD, unclear root cause | Deep exploration → specs → Agent Teams → CI/CD verification | 2-8 hrs |

**Tier detection is investigation-based, not keyword-based.** The orchestrator spends 5 minutes reading your codebase before deciding. A "fix bug" that's actually an architecture flaw gets automatically escalated to STANDARD.

## Key Features

### Investigation-First Tier Detection

Doesn't judge tasks by their description. Investigates first (memory, code, specs, git history), then recommends a tier with evidence. You can override with `--quick` or `--deep`.

### 7 Embedded Verification Rules

Extracted from hundreds of real development prompts. Built into every phase, so you never need to remind the AI to "verify" or "check for regressions":

1. **Double-Verify** — Every "done" claim backed by fresh test output with specific counts
2. **Audit-Driven Fixing** — Test fails? Check if the test is wrong first, then the code
3. **Root Cause Depth** — Don't patch symptoms. Find the design-level issue
4. **Regression Paranoia** — Full test suite after EVERY change. New failure = instant investigation
5. **CICD Awareness** — Changes only "done" when CI pipeline passes
6. **Closed-Loop Completion** — Every cycle closes its own loop (like K8s controllers)
7. **Cross-Session Persistence** — Search memory before starting, save knowledge after finishing

### Spec-Driven Development (OpenSpec)

For STANDARD and DEEP tiers, creates formal specifications before writing code:
- `proposal.md` — Why this change, what's the scope
- `specs/` — Given/When/Then scenarios with edge cases
- `design.md` — Technical approach with trade-offs
- `tasks.md` — TDD implementation checklist

Specs persist across sessions. Archive merges them into a living system document.

### Agent Teams (DEEP Tier)

Automatically upgrades from subagents to Agent Teams when:
- Debugging requires testing competing hypotheses (teammates disprove each other)
- Implementation touches 3+ independent layers (each teammate owns a layer)
- Code review needs multiple perspectives (security + performance + test coverage)

### Two Developer Checkpoints

| Checkpoint | When | What You Do | Time |
|-----------|------|-------------|------|
| Spec Review | After specs generated | Confirm direction, add/remove scenarios | ~2 min |
| PR Review | After implementation complete | Review diff, test evidence, approve | ~5 min |

Everything between is fully automated.

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

Copy the skill and command to your Claude Code config:

```bash
# Copy skill
mkdir -p ~/.claude/skills/dev-orchestrator
cp skills/dev-orchestrator/SKILL.md ~/.claude/skills/dev-orchestrator/

# Copy command
cp commands/dev.md ~/.claude/commands/

# Optional: Enable Agent Teams
# Add to ~/.claude/settings.json under "env":
#   "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
```

Restart Claude Code to load the new skill.

### Option C: Per-Project Install

For project-scoped installation:

```bash
cd your-project
mkdir -p .claude/skills/dev-orchestrator
cp skills/dev-orchestrator/SKILL.md .claude/skills/dev-orchestrator/
cp commands/dev.md .claude/commands/
```

## Usage

### Start Any Development Task

```
/dev "add dark mode with system preference detection"
```

### Override Tier Detection

```
/dev --quick "fix typo in error message"
/dev --deep "redesign payment processing pipeline"
```

### Skip Specs (for non-behavioral changes)

```
/dev --no-spec "refactor auth module to reduce duplication"
```

### Skip PR (direct commit)

```
/dev --no-pr "fix CSS alignment on login page"
```

## How It Works

### Phase 0: Investigate (all tiers)

Before deciding anything, the orchestrator reads your codebase:
1. Searches memory for prior context on this topic
2. Reads relevant source files
3. Checks existing specs (`openspec/specs/`)
4. Reviews recent git history
5. Assesses: surface issue or architectural?

Presents evidence-based tier recommendation. You can accept or override.

### QUICK Path (bug fixes)

1. **Root cause investigation** — systematic debugging, not guessing
2. **Escalation check** — if it's actually a design issue, auto-upgrades tier
3. **TDD fix** — failing test → minimal fix → verify
4. **Full regression check** — all tests, not just the new one
5. **Auto-commit** with descriptive message
6. **Save to memory** — root cause + fix for future reference

### STANDARD Path (features)

1. **OpenSpec propose** — creates specs, design, tasks
2. **You review specs** (~2 min checkpoint)
3. **Generate TDD plan** — each task is 2-5 minutes
4. **Create isolated worktree** — clean baseline
5. **Subagent execution** — per task: implementer → spec reviewer → quality reviewer
6. **Double-verify** — full test suite + regression scan + scope audit
7. **Code review** — dispatch reviewer subagent
8. **Create PR** — you review (~5 min checkpoint)
9. **Archive specs** — merge into living system documentation
10. **Save memory** — decisions and patterns for future sessions

### DEEP Path (system changes)

Same as STANDARD, plus:
- Deep codebase exploration (2-3 parallel explorer agents)
- Runtime investigation (EC2, containers, logs)
- Agent Teams for competing hypotheses or cross-layer work
- CI/CD pipeline verification after PR merge
- Detailed session report with business-goal structure

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

The skill works by invoking other skills by name. If you use different plugins or have custom skills, edit the SKILL.md to reference your preferred tools.

## Advantages

| vs. Manual Skill Chaining | vs. No Framework |
|---------------------------|-----------------|
| One command instead of remembering 10+ skill invocations | Structured specs instead of scattered chat requirements |
| Investigation-first detection instead of guessing task complexity | TDD and regression protection built in |
| 7 verification rules fire automatically | Root cause investigation instead of symptom patching |
| Agent Teams upgrade automatically when needed | Cross-session memory preserves context |
| 2 checkpoints instead of constant supervision | CI/CD verification ensures deployment persistence |

## Roadmap

- [x] v0.1.0 — Core orchestrator with 3 tiers + 7 rules
- [ ] v0.2.0 — Refined tier detection from real-world testing
- [ ] v0.3.0 — Cursor/Windsurf cross-tool support
- [ ] v1.0.0 — Stable API, submitted to Anthropic marketplace

## License

MIT
