# SHIP Definition of Done (DoD)

## Metadata

- Run ID: `<ship-run-id>`
- Created at: `<YYYY-MM-DDTHH:MM:SSZ>`
- Spec reference: `01-spec.md`

## Done statement

The task is done only when all oracle commands below pass and all acceptance criteria are satisfied.

## Acceptance criteria mapping

| AC ID | Requirement | Oracle IDs |
| --- | --- | --- |
| AC-1 | `<requirement>` | ORC-001 |
| AC-2 | `<requirement>` | ORC-002 |

## Oracle command set (machine-checkable)

| Oracle ID | Command | Expected result | Status | Last run | Notes |
| --- | --- | --- | --- | --- | --- |
| ORC-001 | `<command>` | Exit code 0 | pending | never | |
| ORC-002 | `<command>` | Exit code 0 | pending | never | |

## Verification policy

1. Run all oracle commands in order.
2. On failure, fix immediately and rerun failed commands, then rerun full set.
3. Record evidence in `06-verify-log.md` and fix cycles in `07-fix-log.md`.

## Gate checklist

- [ ] Every acceptance criterion maps to oracle commands.
- [ ] Every oracle command has a concrete expected result.
- [ ] Latest full oracle run is all pass.
- [ ] `08-ship-report.md` includes verification evidence.
