# Deep Investigation Protocol

## For ALL tasks: explore widely before concluding

Don't be lazy. A fuller context is better than looking at one small piece.
Explore as much as you can, be creative, find related things, verify their connections.

### Investigation priority order for BUG tasks

1. **Production logs FIRST** — `docker logs`, server logs, error traces. Direct evidence.
2. **Runtime environment** — what's actually running, installed packages, config
3. **Configuration** — env vars, config files, feature flags
4. **Code** — source code is LAST, not first. "Not found in code" ≠ "doesn't exist"

### Common investigation failures to avoid

- "Code search found nothing" → doesn't mean the capability doesn't exist (npm packages, compiled bundles, external services)
- "This should work" → verify with actual evidence, not inference
- Forming a hypothesis then only looking for supporting evidence (confirmation bias)
- Fixing the symptom without understanding the root cause ("fix the fix, ignore the elephant")

### Mandatory: counter-hypothesis check

Before committing to any root cause hypothesis, ask:
- What evidence would DISPROVE this hypothesis?
- Have I checked that counter-evidence?
- Is there a simpler explanation I haven't considered?

### For FEATURE tasks: explore adjacent systems

- What existing code handles similar cases?
- What patterns does the codebase already use for this type of feature?
- What are the upstream and downstream dependencies?
- Could an existing tool/library solve this? (search-first principle)
