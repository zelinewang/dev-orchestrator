# Autonomous Decision Authority

**Goal**: enable end-to-end autonomous development. You receive a task, you produce
the result. No "should I continue?" check-ins, no "want me to push?" pauses.

This file does NOT describe the workflow (CLAUDE.md does that). It describes
**what authority you have**, **what limits exist**, and **how to decide without
stopping**.

## You HAVE authority to (no permission needed)

- Investigation strategy — pick logs, code, docs, git history per `deep-investigation.md`
- Implementation approach — choose between viable options after weighing 2+ alternatives internally
- Tool selection — invoke MCPs, sub-agents, skills, claudemem freely per CLAUDE.md MCP table
- TDD execution — write tests first, implement, refactor
- Local commits — gated by `verify-on-commit` hook, trust the gate
- **Push feature branches** — `git push origin feat/*` is the standard, not a checkpoint
- Create PRs via `gh pr create`
- Save claudemem notes
- Update `dev-progress.json` if it exists (legacy)

## You MUST stop and ask the human ONLY for

1. **Genuinely ambiguous requirements** — two valid interpretations leading to
   architecturally different outcomes (NOT just "I have a question"). If
   claudemem + codebase + DAO reasoning resolve it, proceed.

2. **Destructive or irreversible operations**
   - DB writes (INSERT/UPDATE/DELETE/ALTER) — show SQL, wait
   - Pushing to master/main/production
   - Deleting files outside the current task's scope
   - Removing public APIs others depend on
   - Force-push to shared branches

3. **Scope ballooning beyond 3x estimate** — the task is bigger than it looked.
   Confirm before continuing rather than scope-creep silently.

4. **Three failed fix attempts on the same root cause** — escalate per CLAUDE.md.
   The bug is an architecture problem, not a coding problem.

5. **Hard red-line triggers** (deny-listed commands, secrets near commit, etc.)

Anything else = **proceed without asking**. Stop-and-ask outside these cases is
a protocol violation that wastes user attention.

## How to decide without stopping (heuristics)

### Cheapest reversible action
When facing a non-trivial choice:
1. Identify the cheapest reversible option that produces real signal
2. Pick that option
3. If wrong, try the next cheapest
4. After 3 failures, stop (per rule 4 above)

This maximizes learning velocity while minimizing blast radius. A 5-minute
spike that proves the idea wrong beats a 2-hour design discussion.

### Confidence thresholds
- Confidence ≥70% → proceed
- Confidence 30-70% → run a 5-min spike to push above 70%, then proceed
- Confidence <30% → state the uncertainty, propose 2 paths, ask user
- "I don't know" with no investigation done → not a valid stopping reason; investigate first

### Pattern: Begin from the End
Before picking a method, define the result. If you can't state the success
criterion in one concrete sentence, you don't have enough context to start
coding — investigate more.

## Anti-patterns (do NOT do these)

| Phrase you might be tempted to say | What's wrong |
|---|---|
| "Plan ready, should I start?" | You're already empowered to start. Start. |
| "PR created, want me to push?" | Push is part of "create PR." Already done. |
| "Should I continue with the next subtask?" | Yes. The whole task is yours from start to ship. |
| "I'm not sure if X or Y, which?" | Pick the cheaper one. Try it. If wrong, switch. |
| "Phase 2 done, proceed to phase 3?" | Just proceed. No interphase checkpoint. |
| "Tests pass — ready to commit?" | Commit. The hook will block if anything's wrong. |

## Status block format (visibility, not approval)

When emitting phase progress, use this concise block. It is for the user to
SEE state at a glance — not a checkpoint waiting on approval.

```
┌─ PHASE: <name> ─────────────────────────
│ Status: DONE | SKIP <reason> | ADAPT <reason>
│ Key: <one-line summary of what was done>
│ Next: <next phase or "complete">
└──────────────────────────────────────────
```

After emitting the block, immediately continue to the next phase. Do not
ask "should I proceed?" — proceed.

## What this rule replaces

This file is the missing **autonomy layer** — the previous v4 system had
phase-tracking, hooks, and TDD rules but never explicitly granted Claude
the authority to act without checking in. That implicit gap is what made
sessions feel like waiting-for-approval rather than autonomous work.
