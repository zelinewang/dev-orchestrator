# Design: v2 Self-Enforcing Protocol

## Architecture

The v2 protocol maintains the same 3-stage structure (UNDERSTAND → BUILD → DELIVER) but adds:

```
P0: PRE-CHECK → P1: INVESTIGATE → P2: CLASSIFY → P3: BRAINSTORM
    ── CHECKPOINT 1 ──
P6: SETUP → P7: EXECUTE
    ── GATE ──
P8: VERIFY → P9: SHIP
    ── CHECKPOINT 2 ──
P10: ARCHIVE
```

### Task Type Routing

| Type | Evidence | Key Differences |
|------|----------|----------------|
| DEVELOP | Code change needed | Full TDD + worktree + PR |
| RESEARCH | Investigate/document/learn | No TDD/worktree, keep brainstorm/verify/wrapup |
| CICD | Pipeline/infra/deploy | No TDD, add dry-run + rollback verification |

### Phase Status Blocks (Enforcement)

Every phase outputs:
```
┌─ P<N>: <NAME> ────────────────────────────────
│ Status: DONE | SKIP <reason> | ADAPT <explanation>
│ Task: <type> | Tier: <tier>
│ Key actions: <what was done>
│ Next: P<N+1>
└────────────────────────────────────────────────
```

### Compression Strategy

Used table-heavy format (104 table rows in 311 lines) to maximize information density while minimizing line count. Key technique: one table row represents all 3 task types, replacing 3 paragraphs.

## Files Modified

| File | Before | After | Change |
|------|--------|-------|--------|
| `skills/dev-orchestrator/SKILL.md` | 320 lines (code-only) | 311 lines (3 task types + enforcement) | Rewrite |
| `scripts/verify-dev.sh` | 129 lines (develop only) | 179 lines (+research +cicd modes) | Extended |
| `commands/dev.md` | 4 flags | 6 flags (+--research +--cicd) | Updated |

## Key Design Decisions

1. **Status blocks, not compliance checklist** — Per-phase enforcement (proactive) over end-of-session checklist (reactive). Checklist deferred for future if gaps remain.
2. **Same phase structure, different adaptations** — All task types go through P0-P10, but each phase adapts. This keeps the protocol learnable (one structure to remember).
3. **Brainstorm renamed to MANDATORY** — "Pre-Phase 1" implied optional. Now "P3: BRAINSTORM (MANDATORY)".
4. **Clean P0-P10 numbering** — Eliminated confusing "Pre-Phase 1" and "Phase 0.5" naming.
5. **New override flags** — `--research` and `--cicd` for explicit task type forcing.
