# Development Workflow Phases

Every development task follows these phases. Emit a status block after each.

## Phases

1. **Investigate** — Read code, search claudemem, check docs (context7), read git log
2. **Plan** — State intent + success criteria + affected files in ONE status block
3. **Execute** — TDD per subtask: write failing test → make it pass → verify → commit
4. **Verify** — Run verify-dev.sh (auto-enforced by pre-commit hook). Manual: /verify
5. **Ship** — Push feature branch, create PR, update .claude/dev-progress.json

## Intent Routing

Route by intent, not file count:
- **Building** something new → all 5 phases, brainstorm approaches first
- **Fixing** something broken → evidence-first: investigate → root-cause → TDD fix → verify
- **Trivial** change (typo, config) → skip to Execute

## Status Block Format

After each phase, emit:
```
┌─ PHASE: <name> ─────────────────────────
│ Status: DONE | SKIP <reason>
│ Key: <what was done>
│ Next: <next phase>
└──────────────────────────────────────────
```

## Escalation

- 3 failed fix attempts → stop, the bug is an architecture problem, escalate to build-intent
- Online service down → hotfix/rollback first, investigate after
- Offline pipeline failure → NOT emergency, fix properly
