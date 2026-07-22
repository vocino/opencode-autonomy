---
description: Fix — quick repair with verification loop
agent: build
---

Fix: $ARGUMENTS

## Protocol

1. **Understand context** — Read relevant files, @explore for related code, check recent git diff
2. **TodoWrite if 3+ steps** — ONE in_progress at a time
3. **Batch fix** — Related changes together (3-5 files), follow existing patterns
4. **Verify loop** — Run `bash scripts/detect-oracle.sh` or infer from package.json:
   - lint, typecheck, test, build
   - Rerun after fixes, loop until green or 3x same error
5. **Report** — What changed, what verified, final status

Don't ask permission for ordinary fixes. Start now.
