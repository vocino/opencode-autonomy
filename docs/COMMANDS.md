# Commands — opencode-autonomy

Custom commands are markdown files in `~/.config/opencode/commands/` or `.opencode/commands/`. Invoke via `/commandname` in TUI.

This repo provides 6 high-autonomy commands.

## `/ship <task>`

**Agent:** autonomous  
**Purpose:** Full autonomous closed-loop delivery — main workhorse

**Template:**
1. Concept: capture goal + constraints in `01-spec.md`
2. Spec: fill scope/risks/acceptance criteria from template
3. Plan: TodoWrite + `03-plan.md`
4. Decompose: batch map in `04-decomposition.md`
5. Implement: execute batches and log changes
6. Verify: run oracle commands and log pass/fail
7. Fix: repair failures and rerun verification
8. Ship: final report + evidence in `08-ship-report.md`

**Usage:**
```
/ship Implement markdown preview with live reload
/ship Add JWT refresh token rotation and migrate DB
/ship Fix settings crash when email empty
```

**When to use:** Most feature work, bug fixes, refactors where you want end-to-end shipping without stopping.

## `/verify [run-dir]`

**Agent:** fixer  
**Purpose:** Machine-checkable DoD verification and fix loop

**Template:**
1. Resolve SHIP run directory (explicit arg or latest `.opencode/state/ship/<run-id>/`)
2. Load `02-dod.md` (create from template if missing)
3. Detect commands with `bash scripts/detect-oracle.sh`
4. Merge + dedupe command list from detector and DoD
5. Execute commands, record status in `06-verify-log.md`
6. If failures: fix, append `07-fix-log.md`, rerun until green

**Usage:**
```
/verify
/verify .opencode/state/ship/feature-auth-refresh
```

**When to use:** During `/ship` loops, before handoff, or whenever you need objective pass/fail evidence.

## `/autofix [scope]`

**Agent:** fixer  
**Purpose:** Automatically fix lint, types, tests

**Template:**
1. Detect project type: `ls package.json pyproject.toml Makefile`
2. Scripts: `cat package.json | grep scripts`
3. Loop:
   - lint: `npm run lint` / `ruff check --fix` → fix → rerun
   - types: `tsc --noEmit` / `mypy .` → fix → rerun
   - tests: `npm test` / `pytest` → fix → rerun
   - build: `npm run build` → fix
4. Loop until all green or 3x same error

**Usage:**
```
/autofix
/autofix auth module
/autofix after merging PR
```

**When to use:** After big edits, after merge, when CI fails, before commit.

## `/ultrawork <task>`

**Agent:** ultrawork  
**Purpose:** Maximum persistence, 400 steps, vague ideas → full implementation

**Phases:**
- Phase 1: Deep discovery (parallel @explore for structure, similar features, configs, `git status`)
- Phase 2: Plan (TodoWrite 5-15 todos)
- Phase 3: Implementation (batch 5+ files, follow patterns, add imports/types/tests)
- Phase 4: Verification loop (lint → typecheck → tests → build → fix loop)
- Phase 5: Report (files changed, verified commands, human input needed, commit msg, assumptions)

**Usage:**
```
/ultrawork Build a full habit tracker app with streaks and notifications
/ultrawork Migrate from REST to tRPC, update all clients
/ultrawork Research and implement best practice for image optimization in Next.js
```

**When to use:** Whole projects, migrations, large refactors, vague ideas needing research + implementation.

**Stop conditions:** Only stop when complete+verified, true blocker (creds down, contradictory reqs), or 3x same error loop.

## `/fix <issue>`

**Agent:** build  
**Purpose:** Quick fix single issue

**Protocol:**
- Understand context (read files, @explore grep)
- TodoWrite if 3+ steps
- Batch related changes
- Fix lint/types/tests broken by change
- Verify

**Usage:**
```
/fix Settings crashes when email is empty
/fix Button variant primary not applying dark mode
```

**When to use:** Small focused bugs, quick tweaks.

## `/review [files]`

**Agent:** reviewer (read-only)  
**Purpose:** Strict code review

**Steps:**
- `git status`, `git diff HEAD --stat`, `git diff HEAD | head -500`
- @explore for context
- Report critical/major/minor with file:line

**Usage:**
```
/review
/review auth module
/review pr 123
```

**When to use:** Before PR, after autonomous work to double-check.

## Creating your own

File: `~/.config/opencode/commands/my-cmd.md`

```markdown
---
description: What it does
agent: build # or autonomous, fixer, etc
model: anthropic/claude-sonnet-4-5 # optional override
---

Do $ARGUMENTS

Steps:
- Check $1, $2 positional args
- Use !`command` to inject shell output: !`git log --oneline -10`
- Use @file for file refs: @src/components/Button.tsx

Template supports:
- $ARGUMENTS — all args after command
- $1, $2, $3 — positional
- !`cmd` — bash output at invocation time (brittle if file may not exist; prefer detecting inside agent via bash tool)
- @path — file content
```

See https://opencode.ai/docs/commands for full spec.

## Tips

- Commands deep-merge: global `~/.config/opencode/commands/` + project `.opencode/commands/` (project overrides)
- Override built-ins: name your file same as built-in (`undo.md`) to override.
- Use `subtask: true` in frontmatter to force subagent invocation even if agent mode primary (isolates context).
- Model override per command useful: use haiku for quick review, sonnet/opus for heavy work.
