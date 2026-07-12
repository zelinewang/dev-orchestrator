# /dev — AI Development Orchestrator

A Claude Code plugin that runs the whole development loop from one command —
investigate → plan → TDD → verify → ship — and backs each quality gate with a
deterministic host-side hook, not a prompt reminder the model can forget.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-8A2BE2.svg)](https://docs.claude.com/en/docs/claude-code/overview)
[![Shell](https://img.shields.io/github/languages/top/zelinewang/dev-orchestrator.svg)](https://github.com/zelinewang/dev-orchestrator)

You describe a task; the orchestrator classifies its intent, picks a depth,
investigates before it writes code, drives each subtask through TDD, and refuses
to let a broken commit through. The point isn't another prompt telling the model
to behave — it's that the enforcement lives in hooks that run on your machine at
zero context cost.

```text
/dev "add user authentication with JWT and refresh tokens"

┌─ INVESTIGATE ───────────────────────────
│ Status: DONE | Sources: memory, code, docs, git
│ Next: PLAN
└─────────────────────────────────────────
┌─ PLAN ──────────────────────────────────
│ Intent: build | Depth: deep | 8 subtasks, TDD each
│ Next: EXECUTE
└─────────────────────────────────────────
[TDD 1/8 → … → 8/8 ✓]  47/47 tests passing, 0 regressions
┌─ SHIP ──────────────────────────────────
│ PR #142 created. CI green.
└─────────────────────────────────────────
```

That flow is the skill's interface. The gates behind it are real: the
pre-commit hook runs `verify-dev.sh`, which auto-detects your test command,
runs the full suite, checks that new source ships with new tests, and blocks
the commit on failure. Run it yourself against any repo:

```console
$ bash scripts/verify-dev.sh .
=== /dev Verification Gate (mode: develop) ===

[RULE 1] Full test suite...
  Running: go test ./... -count=1
  ✓ Tests passed
    ok  	demo	1.241s

[RULE 4] New code vs new tests...
  New source files: 0
  New test files:   0

[RULE 6] Scope check...
  No changes vs origin/master

[QUALITY] Checking for debug leftovers...
  ✓ No debug leftovers

===========================================
  VERIFIED ✓ — 0 failures, 0 warnings
===========================================
```

## Architecture: 4-Layer Enforcement

Core insight, drawn from the research below: **deterministic infrastructure beats
prompt-level guidance.** The workflow is enforced at four layers, strongest first.

```
┌─────────────────────────────────────────────────────┐
│  Layer 4: File-Backed State (survives everything)    │
│  .claude/dev-progress/<branch>.json (optional)       │
├─────────────────────────────────────────────────────┤
│  Layer 3: Hooks (deterministic, zero context)        │
│  SessionStart → inject progress                      │
│  PreToolUse   → verify-on-commit gate (exit 2)       │
│  PostToolUse  → auto-format Python                   │
│  Stop         → persist state                        │
├─────────────────────────────────────────────────────┤
│  Layer 2: Rules + CLAUDE.md (compact-safe guidance)  │
│  autonomous-decisions · deep-investigation ·         │
│  tdd-protocol · wrapup-retrospective                 │
├─────────────────────────────────────────────────────┤
│  Layer 1: /dev Skill (on-demand, full guidance)      │
│  791 lines — loaded only when /dev is invoked        │
└─────────────────────────────────────────────────────┘
```

| Layer | Nature | Survives compact? | Context cost |
|-------|--------|-------------------|-------------|
| Hooks | Deterministic (host process) | Always active | Zero |
| Rules + CLAUDE.md | Probabilistic, re-injected each session | Yes | ~900 tokens |
| /dev Skill | Probabilistic, ephemeral | No | ~3,000 tokens (on-demand) |

Hooks are the only layer that can't be skipped; rules and the skill are guidance
that a host hook ultimately backstops.

## How It Works

### Intent routing

Route by intent, not file count:

| Intent | When | Workflow |
|--------|------|---------|
| **Build** | New feature, architecture | Full: investigate → plan → execute → verify → ship |
| **Fix** | Bug, hotfix, incident | Evidence-first: logs → root cause → TDD fix → verify |
| **Research** | Investigate, analyze, learn | Investigate → notes → report (no TDD/worktree) |
| **Deploy** | Pipeline, infra, config | Impact + rollback → dry-run → apply → monitor |
| **Trivial** | Typo, comment, config | Skip straight to execute |

### Phases

1. **Investigate** — search claudemem, read code, check docs, read git log. For bugs, **production logs first**.
2. **Plan** — one status block: intent + success criteria + affected files.
3. **Execute** — TDD per subtask: RED → GREEN → VERIFY → COMMIT, with language-aware reviewers.
4. **Verify** — enforced by the pre-commit hook (`exit 2` if `verify-dev.sh` fails). Manual: `/verify`.
5. **Ship** — push the feature branch, open a PR, record progress.

`--deep` adds parallel agent teams for independent subtasks, CI-wait scheduling,
language-matched reviewers, and OpenSpec integration. Depth and intent are
auto-detected; flags (`--quick`, `--deep`, `--research`, `--cicd`, `--no-spec`,
`--no-pr`) override.

## Hooks (Deterministic Layer)

All hooks run on the host at zero context cost and fire automatically.

| Hook | Event | Does |
|------|-------|------|
| `dev-verify-on-commit.sh` | PreToolUse:Bash | On `git commit`: `verify-dev.sh` failure → `exit 2` (hard block); `ruff` lint issues → non-blocking warning |
| `dev-commit-test-pairing.sh` | PreToolUse:Bash | Flags source commits that carry no accompanying test change |
| `dev-quality-gate.sh` | PostToolUse:Edit\|Write | Auto-formats edited Python with `ruff format` (falls back to `black`); silent, non-blocking |
| `dev-session-start.sh` | SessionStart | Injects branch-scoped progress so a new session resumes mid-task |
| `dev-session-end.sh` | Stop | Persists the session's `updated_at` for continuity |

## Rules (Compact-Safe Guidance)

Loaded every session and re-injected after context compaction — durable guidance
that the hooks backstop.

| File | Purpose | Lines |
|------|---------|-------|
| `autonomous-decisions.md` | Decision authority: what to do without asking vs. hard stop-and-ask triggers | 101 |
| `deep-investigation.md` | Logs-first for bugs; mandatory counter-hypothesis check | 34 |
| `tdd-protocol.md` | VERIFY + COMMIT steps; when TDD applies by intent | 19 |
| `wrapup-retrospective.md` | 6-dimension session retrospective template | 62 |

## Cross-Session State

Progress is grounded in git log + claudemem notes; an **optional** branch-scoped
JSON file (`.claude/dev-progress/<branch>.json`) can carry explicit phase/subtask
state for the SessionStart hook to re-inject:

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

## Wrapup Retrospective

Every `/wrapup` runs a retrospective across six dimensions — phase compliance,
investigation quality, user corrections (count + root cause), tool utilization,
hook effectiveness, and workflow-design feedback — so each session doubles as a
test of the workflow itself.

## Installation

This is a Claude Code plugin (`.claude-plugin/plugin.json`). Two ways to install:

### Option A — sync from your config repo (existing users)

```bash
cd ~/claude-code-config && git pull && bash install.sh
```

### Option B — manual

```bash
# Hooks (register in ~/.claude/settings.json — JSON snippets are in hooks/)
cp hooks/dev-*.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/dev-*.sh

# Rules
mkdir -p ~/.claude/rules/dev-workflow && cp rules/dev-workflow/*.md ~/.claude/rules/dev-workflow/

# Scripts
cp scripts/*.sh ~/.claude/scripts/ && chmod +x ~/.claude/scripts/*.sh

# Skill + command
mkdir -p ~/.claude/skills/dev-orchestrator
cp skills/dev-orchestrator/SKILL.md ~/.claude/skills/dev-orchestrator/
cp commands/dev.md ~/.claude/commands/
```

### Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) with a recent Opus model
- `ruff` on the host (`pip install ruff`) — for the Python quality-gate hook
- [superpowers](https://github.com/obra/superpowers) — TDD / debugging / planning skills
- [claudemem](https://github.com/zelinewang/claudemem) — cross-session memory (recommended)

## Usage

```bash
/dev "add dark mode with system preference detection"
/dev --deep "redesign the payment processing pipeline"
/dev "fix the 500 error in the video upload endpoint"
/dev --research "how does our auth system handle token rotation"
```

## Design Principles

1. **Deterministic enforcement > prompt guidance** (Microsoft AGT measured 0% policy violation with agent-side enforcement vs. 27% without).
2. **Progressive enforcement** — observe → measure → selectively enforce.
3. **Design for obsolescence** — every hook carries an explicit "when to remove" condition.
4. **Feedforward + feedback** — rules guide behavior, hooks catch what slips (Fowler).
5. **File-backed state > in-context state** — progress survives compaction and restarts.

## Research Basis

The 4-layer design was drawn from 19 primary sources — Anthropic and OpenAI
harness-engineering writeups, five arXiv papers, industry practice (Stripe,
Sourcegraph, Vercel), practitioner essays (Hashimoto, Willison, Fowler), and
governance frameworks (Microsoft AGT, NIST). The recurring finding: move the
guarantee out of the prompt and into the harness.

## Roadmap

- [x] v1 — core orchestrator, tiers, verification rules
- [x] v2 — TDD protocol + `verify-dev.sh` enforcement
- [x] v3 — zero-checkpoint continuity contract
- [x] **v4 — 4-layer harness (hooks + rules + state + skill)**
- [ ] v4.1 — compliance-measurement baseline
- [ ] v4.2 — instruction fade-out countermeasure (periodic re-injection)
- [ ] v5 — adaptive harness that removes its own scaffolding as models improve

## License

[MIT](LICENSE) © Zane Wang
