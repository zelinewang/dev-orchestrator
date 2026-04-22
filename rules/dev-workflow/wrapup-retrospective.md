# Wrapup Retrospective

Every /wrapup MUST include a "## Workflow Retrospective" section.
Every session is a test session for the dev workflow itself.

## Evaluation dimensions (answer honestly)

### A. Phase compliance
1. Did I follow investigate→plan→execute→verify→ship? Which phases skipped and why?
2. For bug tasks: did I check production LOGS before searching code? (deep-investigation rule)
3. Did I emit status blocks after each phase?

### B. Investigation quality
4. Did I search claudemem before starting? What did I find/miss?
5. Did I use available MCPs when relevant? (context7 for docs, fetch for APIs, DB MCPs for data)
6. Did I check existing codebase patterns before writing new code? (search-first principle)
7. Did I explore WIDELY enough, or tunnel-visioned on first hypothesis? (counter-hypothesis check)
8. For bugs: did I verify assumptions with EVIDENCE, or rely on inference?

### C. User corrections
9. How many times did user redirect my approach? (0 = great, 1 = ok, 2+ = investigate why)
10. What was the root cause of each correction? (shallow investigation, wrong assumption, missed context, confirmation bias, other)

### D. Tool & context utilization
11. Which tools/MCPs/skills/agents did I use? Which SHOULD I have used but didn't?
12. Did I use worktree isolation when working in shared repo? (CLAUDE.md rule)
13. Did I make good use of subagents for parallel work?

### E. Hook effectiveness
14. Fill the hook table below.

### F. Workflow design feedback
15. Was this a workflow DESIGN problem (missing step/rule) or EXECUTION problem (knew the rule, didn't follow it)?
16. One specific improvement: what rule/hook/skill change would prevent the biggest mistake this session?

## Output format

```
### Phase compliance: [score/3]
- [details]

### Investigation quality: [score/5]
- [details, especially what was missed]

### User corrections: [count] — root cause: [pattern]

### Tool utilization gaps
- Used: [list]
- Should have used: [list with reason]

### Hook effectiveness
| Hook | Triggered? | Correct? | Notes |
|------|-----------|---------|-------|
| SessionStart | Y/N | ✅/⚠️/❌ | ... |
| verify-on-commit | Y/N | ✅/⚠️/❌ | ... |
| quality-gate | Y/N | ✅/⚠️/❌ | ... |
| session-end | Y/N | ✅/⚠️/❌ | ... |

### Workflow improvement
- Design vs execution: [which]
- Suggested change: [specific, actionable]
```
