---
description: Autofix - automatically fix lint, type, and test failures in loop
agent: fixer
---

Run full autofix loop for $ARGUMENTS (if empty, fix everything failing).

## Steps:

1. Detect project type: check for package.json, pyproject.toml, Makefile. Read package.json scripts section.

2. Run in order, fix, loop:
   - **Lint**: `npm run lint` / `yarn lint` / `uv run ruff check --fix .` etc. Fix reported issues. Rerun until clean or 3 attempts.
   - **Types**: `tsc --noEmit` or `npm run typecheck` or `mypy .`. Fix type errors. Batch 3-5 files. Rerun.
   - **Tests**: `npm test` / `pytest` / etc. Fix failing tests. If pre-existing unrelated failures, note them.
   - **Build**: `npm run build` if exists - ensure it passes.

3. Keep looping: if fixing types introduces lint errors, fix again. Continue until all green or same error 3x.

4. Final: list fixes, commands run + results, status.

Be autonomous, batch fixes, don't ask for approval on obvious fixes. Start now.
