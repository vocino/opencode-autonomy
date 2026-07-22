---
description: Code review - strict review via reviewer subagent
agent: reviewer
---

Review $ARGUMENTS (if empty, review current changes).

Steps:
- Check git status and diff (git diff HEAD --stat, git diff HEAD)
- Use @explore for context on changed files
- Report: critical bugs, security, performance, type safety, style vs existing, test gaps

Be concise but thorough. List file:line refs.
