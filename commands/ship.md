---
description: Ship - max autonomy closed loop from concept to verifiable outcome with artifact gates
agent: autonomous
---

You are in SHIP mode - isolated but fully empowered. During autonomous flow, do not introduce ask-gates for routine implementation decisions.

## Goal

$ARGUMENTS

## SHIP state root (required)

- Create and use a persistent state directory for this run:
  - `.opencode/state/ship/<run-id>/`
- Treat this directory as memory artifacts for long runs and compaction recovery.

Required artifacts:
- `01-spec.md`
- `02-dod.md`
- `03-plan.md`
- `04-decomposition.md`
- `05-implementation-log.md`
- `06-verify-log.md`
- `07-fix-log.md`
- `08-ship-report.md`

## Closed-loop phases with gates

1. **Concept**
   - Parse user intent into a concrete outcome statement and constraints.
   - Gather world context: repo structure, docs, existing patterns, toolchain, current git state.
   - **Gate:** Concept summary and constraints are written in `01-spec.md`.

2. **Spec**
   - Instantiate `01-spec.md` from `templates/ship/SPEC.template.md` (or config-installed equivalent).
   - Fill scope, assumptions, non-goals, risks, touched areas, and acceptance criteria.
   - **Gate:** Spec sections complete enough for implementation without further clarification.

3. **Plan**
   - Create TodoWrite list (5-15 items for medium/large work, exactly one `in_progress`).
   - Mirror implementation strategy in `03-plan.md`.
   - **Gate:** Ordered execution plan exists with dependencies and validation notes.

4. **Decompose**
   - Break plan into implementation batches (3-5 related files per batch when possible).
   - Record batches and rollback notes in `04-decomposition.md`.
   - **Gate:** Every planned change is mapped to a batch and verification checkpoint.

5. **Implement**
   - Execute batches end-to-end using existing repo patterns.
   - Log major decisions and changed paths in `05-implementation-log.md`.
   - **Gate:** All scoped work is implemented and ready for verification.

6. **Verify**
   - Instantiate `02-dod.md` from `templates/ship/DOD.template.md` if missing.
   - Use `bash scripts/detect-oracle.sh` to detect oracle commands; merge with task-specific checks.
   - Run `/verify` flow (or equivalent manual execution) and write outcomes to `06-verify-log.md`.
   - **Gate:** Machine-checkable DoD commands are executed with pass/fail status recorded.

7. **Fix**
   - If any oracle command fails, fix immediately (delegate to `@fixer` for large batches), then rerun verify.
   - Record each failure/fix iteration in `07-fix-log.md`.
   - **Gate:** No unresolved verification failures remain.

8. **Ship**
   - Produce final `08-ship-report.md` with: files changed, behavior changes, verification evidence, assumptions, residual risks.
   - Provide conventional commit message suggestion (do not commit unless explicitly asked).
   - **Gate:** All DoD checks pass and report is complete.

## Stop conditions

Stop only when:
- complete + verified (all DoD oracle checks green),
- true blocker (missing credentials, unavailable dependency/service, contradictory requirements),
- or 3x same unresolved error loop after materially different fixes.
