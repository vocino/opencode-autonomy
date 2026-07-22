# Agents — opencode-autonomy

## Overview

OpenCode agents are specialized prompts with tuned permissions, steps, temperature, and tools. Configured in `opencode.json` `agent` object or `agents/*.md` files.

This repo provides 6 agents:

| Agent | Mode | Steps | Temp | Purpose |
|-------|------|-------|------|---------|
| `build` | primary | 200 | 0.2 | Default high-autonomy dev, ships features |
| `autonomous` | primary | 300 | 0.2 | Closed-loop SHIP agent with artifact gates |
| `ultrawork` | primary | 400 | 0.25 | Max persistence, whole projects/migrations |
| `specifier` | subagent | 120 | 0.15 | Creates SPEC and machine-checkable DoD artifacts |
| `fixer` | subagent | 150 | 0.1 | Autofix lint/types/tests loop |
| `reviewer` | subagent | 80 | 0.15 | Strict read-only code review |

Plus built-ins: `plan` (read-only analysis), `explore` (fast read-only search), `general` (multi-step research).

## Switching

- **Tab** cycles primary agents (`build` → `autonomous` → `ultrawork` → `plan`)
- `@agentname` mentions subagent: `@explore Find all auth usage`, `@fixer Fix failing tests`
- `/ship` etc invoke via commands (which set agent internally)

## `build` — default workhorse

**Mode:** primary, steps 200, temp 0.2, `* allow`

Prompt emphasizes:

- Make reasonable assumptions when obvious (package.json, existing patterns)
- Keep working through failures (lint → fix, types → fix, tests → fix)
- Batch 3-5 files, then validate
- No approval for ordinary choices
- Ask only on true ambiguity affecting correctness/safety/scope
- Use TodoWrite for 3+ steps, one in_progress at a time
- Final output: what changed, what verified, commit msg ready (no commit unless asked)
- Never break existing architecture, never pause per file, cleanup temp files

## `autonomous` — ultra-high autonomy

**Mode:** primary, steps 300, temp 0.2, color success

Designed for "take vague idea -> verifiable shipped outcome without stopping".

Protocol:

1. **Concept** - define outcome + constraints in state artifacts
2. **Spec** - write `01-spec.md` from template
3. **Plan** - TodoWrite + `03-plan.md`
4. **Decompose** - map work batches in `04-decomposition.md`
5. **Implement** - execute batches, log in `05-implementation-log.md`
6. **Verify** - run machine-checkable oracle commands into `06-verify-log.md`
7. **Fix** - repair failures and rerun checks, tracked in `07-fix-log.md`
8. **Ship** - publish `08-ship-report.md` with evidence and handoff

Extra capabilities enabled: formatter+lsp, tool_output 5000/200KB, compaction tail 12, batch_tool, subagent_depth 3.

## `ultrawork` — maximum persistence

**Mode:** primary, steps 400, temp 0.25, color accent

Same as autonomous but 400 steps, higher tolerance for long-running tasks. Use for full feature implementations, migrations, large refactors.

Enhanced workflow:

- Discovery phase: parallel @explore for patterns, config, existing implementations
- Planning phase: TodoWrite 5-15 todos
- Implementation: batch execute, mark in_progress ONE at a time
- Verification: build, tests, lint, typecheck — fix failures, repeat
- Report: exhaustive list files changed, logic, commands run, results

## `specifier` — spec and DoD author

**Mode:** subagent, steps 120, temp 0.15, color accent

Purpose:
- Convert concepts into implementation-ready specs
- Create machine-checkable DoD artifacts before coding
- Detect oracle commands via `scripts/detect-oracle.sh`
- Map acceptance criteria to oracle checks

Use when `/ship` starts from ambiguous requirements or when you need stronger done criteria before implementation.

## `fixer` — autofix subagent

**Mode:** subagent, steps 150, temp 0.1, color warning

Given failing output, fixes autonomously.

Protocol:
- Read failing output
- TodoWrite if 3+ failures
- Batch fixes 3-5 files
- Rerun verification after each batch (npm run lint, typecheck, test, build — infer from package.json)
- Loop until green or 3x same error
- No permission ask for obvious fixes

Typical commands inferred:
- Node: `npm run lint`, `tsc --noEmit`, `npm test`, `npm run build`
- Python: `uv run ruff check --fix`, `mypy .`, `pytest`

## `reviewer` — code review subagent

**Mode:** subagent, steps 80, temp 0.15, color info, `edit: deny`

Strict but constructive review:

- Bugs, edge cases
- Security (injection, auth, data exposure)
- Performance regressions
- Type safety, null handling
- Maintainability vs existing patterns
- Test coverage gaps

Process: @explore for context, read diff, list critical/major/minor with file:line.

Do NOT edit code — read-only analysis.

## Creating your own

Use `opencode agent create` interactive, or copy existing md:

```markdown
---
description: What it does — when to use it
mode: subagent
steps: 100
temperature: 0.2
color: accent
permission:
  "*": allow
  edit: deny # if read-only
---

Your prompt here...
```

Save to `~/.config/opencode/agents/my-agent.md` and restart opencode.

See https://opencode.ai/docs/agents for full options (model, prompt, tools, permission, color, hidden).
