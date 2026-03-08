---
description: "End-to-end AI development orchestrator. Auto-detects task tier and chains all skills."
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Agent, WebFetch, Skill, AskUserQuestion
argument-hint: "<task description> [--quick|--deep|--no-spec|--no-pr]"
---

Invoke the `dev-orchestrator` skill with the user's task description.

Pass `$ARGUMENTS` as the task input. The skill handles everything:
investigation, tier detection, execution, verification, and shipping.
