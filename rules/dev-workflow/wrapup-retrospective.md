# Wrapup Retrospective

Every /wrapup MUST include a "## Workflow Retrospective" section.
Every session is a test session for the dev workflow itself.

## Questions (answer honestly)

### Workflow evaluation
1. Did I follow investigate→plan→execute→verify→ship? Which phases skipped and why?
2. Did I explore enough context before forming conclusions? Or jumped to solution too fast?
3. Were there moments where user corrected my direction? What should I have done differently?
4. Did hooks fire correctly? Any missed triggers? Any false positives?

### Root cause of mistakes (if any)
5. What was the core investigation failure? (e.g., didn't check logs, assumed without evidence)
6. Was this a workflow design problem (missing step) or execution problem (knew step, skipped it)?
7. What specific change to rules/hooks/skill would have prevented this mistake?

### Learning extraction
8. What new pattern or lesson should be saved to claudemem?
9. Should any rule be added/modified in dev-workflow/?
10. Should any hook behavior be adjusted?

## Output format

```
### What went well
- [specific examples]

### What went wrong
- [specific examples with root cause]

### Workflow improvement suggestions
- [actionable changes to rules/hooks/skill]

### Hook effectiveness
| Hook | Triggered? | Correct? | Notes |
|------|-----------|---------|-------|
| SessionStart | Y/N | ✅/⚠️/❌ | ... |
| verify-on-commit | Y/N | ✅/⚠️/❌ | ... |
| quality-gate | Y/N | ✅/⚠️/❌ | ... |
| session-end | Y/N | ✅/⚠️/❌ | ... |
```
