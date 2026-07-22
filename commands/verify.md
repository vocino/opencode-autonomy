---
description: Verify SHIP definition of done via detected oracle commands and fix loop
agent: fixer
---

Run SHIP verification for: $ARGUMENTS

## Verification flow

1. Resolve SHIP state directory:
   - If `$ARGUMENTS` points to a SHIP run directory, use it.
   - Otherwise use the latest `.opencode/state/ship/<run-id>/`.

2. Ensure DoD artifact exists:
   - Required file: `<run-id>/02-dod.md`
   - If missing, create from `templates/ship/DOD.template.md` and seed with detected oracle commands.

3. Detect oracle commands:
   - Run `bash scripts/detect-oracle.sh`.
   - Merge detected commands with task-specific commands listed in `02-dod.md`.
   - Deduplicate while preserving priority order.

4. Execute oracle commands in order:
   - Run each command exactly.
   - Record command, exit status, and key evidence in `<run-id>/06-verify-log.md`.
   - Update DoD check status in `02-dod.md` (pass/fail/skipped + notes).

5. Closed loop:
   - If any check fails, fix immediately and rerun failed checks, then full set.
   - Continue until all checks pass, true blocker appears, or 3x same unresolved failure.
   - Append each repair cycle to `<run-id>/07-fix-log.md`.

## Output

- Oracle commands executed and results
- Remaining failures/blockers (if any)
- Final DoD gate status

Do not commit. Verification is complete only when DoD is fully green.
