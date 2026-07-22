---
description: Quick fix - fix specific issue $ARGUMENTS autonomously
agent: build
---

Fix this: $ARGUMENTS

Protocol:
- Understand context (read relevant files, grep for related code via @explore)
- Use TodoWrite if 3+ steps
- Batch related changes
- Fix lint/types/tests that break due to your change
- Verify with appropriate commands
- Report what changed + what verified

Make reasonable assumptions if obvious from repo. Don't ask permission for ordinary choices. Go.
