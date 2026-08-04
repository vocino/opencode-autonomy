---
description: Ship — closed loop from concept to verified outcome
agent: build
---

Goal: $ARGUMENTS

## The closed loop — do not skip phases

1. **Concept** — Parse intent into concrete outcome + constraints. Scan repo structure, package.json scripts, AGENTS.md, git status. Use @explore in parallel if needed.

2. **Plan** — If 3+ steps, create TodoWrite immediately (5-15 todos, ONE in_progress at a time). No file for this, just TodoWrite — that is your memory.

3. **Implement** — Execute in batches of 3-5 related files. Follow existing repo patterns. Log major decisions.

4. **Verify** — Machine-checkable only:
   - Run `bash scripts/detect-oracle.sh` to detect lint/type/test/build commands
   - Add task-specific checks implied by $ARGUMENTS
   - Run each command, capture exit code + evidence
   - This is the DoD: all checks must pass

5. **Fix** — Any failure triggers immediate fix and re-verify loop. Delegate large batches to @fixer. Loop until green or 3x same error.

6. **Version** — semver.org (MAJOR.MINOR.PATCH) for every change:
   - MAJOR = breaking API / incompatible change
   - MINOR = new feature, backwards-compatible
   - PATCH = bugfix, backwards-compatible
   - `0.y.z` = initial dev: MINOR for breaking-ish, PATCH for fix, no arbitrary jumps
   - Map to conventional commits: `fix:` → PATCH, `feat:` → MINOR, `feat!:` or `BREAKING CHANGE:` → MAJOR (MINOR if still 0.y.z with note)
   - When choosing a version, think: what did the user just ship? If it's a fix, it's PATCH. New capability, it's MINOR. This must be in the commit message reasoning.

7. **Ship** — Final report:
   - What changed (files + logic + why)
   - What verified (commands + results)
   - Semver bump: MAJOR/MINOR/PATCH + why per semver.org (use commit type mapping)
   - What needs human input, if anything
   - Assumptions made
   - Conventional commit message ready (do NOT commit unless requested) — message type must match semver choice (fix/feat/feat!)

Stop only when: complete+verified, true blocker, or 3x identical failure after real fixes.
