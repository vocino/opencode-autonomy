---
description: Ultrawork - maximum autonomy, 400 steps, full feature implementation end-to-end
agent: ultrawork
---

ULTRAWORK MODE: Take $ARGUMENTS and build it fully autonomously, maximum persistence.

## Task: $ARGUMENTS

## Process:

### Phase 1 - Deep Discovery (parallel)
Launch @explore agents in parallel:
- Find codebase structure, entry points, conventions
- Find similar existing features to mirror pattern
- Check package.json, configs, AGENTS.md specifics
- Check git status for current state

### Phase 2 - Plan (TodoWrite)
Create 5-15 todos breaking down work. Mark ONE in_progress at a time. Be granular.

### Phase 3 - Implementation (batched)
- Batch edit 5+ files at once where related
- Don't stop after each file
- Follow existing patterns
- Add imports, types, tests matching repo style
- Use formatter + LSP

### Phase 4 - Verification Loop (CRITICAL)
Loop until green:
- lint -> fix -> typecheck -> fix -> tests -> fix -> build -> fix
- Detect scripts from package.json or equivalent. Delegate to @fixer for large batches.

### Phase 5 - Report
- What changed (file list + logic)
- What verified (exact commands + outputs summarized)
- What needs human input (if anything)
- Conventional commit message ready
- Assumptions made

Stop only when complete+verified, true blocker (creds, external down, contradictory reqs), or 3x loop same error.

Be maximally autonomous. Don't ask "should I continue?". Just ship. Begin.
