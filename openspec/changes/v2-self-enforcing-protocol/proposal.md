# Proposal: v2 Self-Enforcing Protocol

## Problem Statement

During a `--deep` research session, self-audit revealed **16% protocol compliance** (8.5/53 checkpoints). The /dev orchestrator protocol was well-designed for code development but had critical gaps:

1. **No task-type awareness** — research/CICD tasks forced into code-only flow (TDD, worktrees, PRs)
2. **Brainstorming always skipped** — "Pre-Phase 1" naming implied it was optional
3. **Plan Mode conflicts** — no priority rules when both /dev and Plan Mode are active
4. **Silent phase skipping** — AI could skip phases without any trace or documentation
5. **No /wrapup enforcement** — DEEP tier's memory requirements were ignored
6. **Skills not invoked** — protocol referenced skills but nothing enforced invocation

## Root Cause Analysis

The protocol assumed all tasks produce code. When non-code tasks enter, every phase either doesn't apply (TDD for research?) or is silently skipped. The lack of visible enforcement means compliance degrades to whatever the AI "feels like doing."

## Proposed Solution

### 1. Task Classification (new P2 phase)
Classify every task as DEVELOP, RESEARCH, or CICD based on investigation evidence. Each type routes through the same phase structure with type-specific adaptations.

### 2. Phase Status Blocks (enforcement mechanism)
Every phase MUST output a formatted status block (DONE/SKIP/ADAPT). No silent skipping allowed. This is the primary enforcement mechanism.

### 3. Per-Type Adaptation Table
A master table defines what each phase means for each task type, replacing the current single-flow assumption.

### 4. Plan Mode Integration
Explicit priority rules: /dev takes priority when both are active.

## Impact

- SKILL.md: Major rewrite (320 → 311 lines, more features in fewer lines)
- verify-dev.sh: Added --research and --cicd verification modes
- commands/dev.md: Updated flags (--research, --cicd)

## Decision

Approved and implemented in session 2026-03-09.
