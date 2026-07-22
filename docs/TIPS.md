# Tips — High-Autonomy OpenCode

## `--auto` flag

```bash
opencode --auto
opencode run --auto "Refactor auth"
```

Auto-approve permissions that are not explicitly denied. Explicit `deny` still enforced. In TUI, command palette → Enable auto-approve.

With our `* allow` config, `--auto` is insurance for per-project restrictive configs.

Alias:

```bash
alias oc='opencode --auto'
alias oca='opencode --agent autonomous --auto'
alias ocw='opencode --agent ultrawork --auto'
```

## TodoWrite

Always use for 3+ steps:

```
- TodoWrite: create list, exactly ONE in_progress at a time, mark completed immediately
- Break into 5-15 granular todos for big tasks
- Helps resume after compaction
```

## Subagents

- `@explore` — fast read-only, codebase search, pattern finding. Use in parallel.
- `@general` — multi-step research, can edit. Use for complex investigations.
- `@fixer` — delegate large fix batches: `@fixer Fix failing tests after auth refactor`
- `@reviewer` — delegate review: `@reviewer Review auth changes`

Subagent depth 3 allows chains:

```
build (primary) → explore (subagent) → general (subagent's subagent) → fixer (deep)
```

## Batching

Don't: edit 1 file → run tests → edit 1 file → run tests

Do: edit 5 related files in parallel (batch_tool enabled) → run full verification (lint+type+test+build) → fix batch → rerun.

## Verification loop

After any implementation:

```bash
# Detect oracle commands for this repo
bash scripts/detect-oracle.sh

# Run in order, fix loop
npm run lint || yarn lint || uv run ruff check .
npx tsc --noEmit || npm run typecheck || uv run mypy .
npm test || yarn test || uv run pytest
npm run build || yarn build
```

If fixing types introduces lint errors, fix again. Loop until green.

## Small model

Set `small_model` to fast/cheap:

- `cursor/claude-haiku-4-5`
- `anthropic/claude-haiku-4-5`
- `openrouter/google/gemini-flash-latest`

Used for title generation, compaction summary. Saves cost/time.

## Large model

Main model for heavy work:

- `meta/muse-spark-1.1` — 1M context, great for large repos (what we use)
- `anthropic/claude-sonnet-4-6` / `claude-opus-4-6` — strong reasoning
- `cursor/composer-2.5` — good balance, Cursor native
- `cursor/gpt-5.6-terra` etc — frontier

Set via `model` or per-agent `model:`.

## Compaction tuning

- `tail_turns: 12` keeps recent turns verbatim — important for long tasks where recent errors matter.
- `reserved: 20000` leaves buffer so compaction doesn't overflow.
- `preserve_recent_tokens: 20000` keeps up to 20k recent tokens verbatim.

If you do 400-step ultrawork, these prevent losing context.

## Tool output limits

Default 2000 lines / 51k bytes truncates long test logs. Raised to 5000 / 204800 for full logs. If still truncated, full output saved to file (path shown in truncated preview) — you can `Read` that file or `grep` it.

## Formatter + LSP

Enabled → auto-format on save, diagnostics. During autonomy, lean on them:

- Don't manually format — let formatter do it
- Check LSP diagnostics for missing imports/types rather than guessing

## Snapshot

`snapshot: true` enables undo/redo in TUI:

```
/undo
/redo
```

Disable only if huge repo and indexing is slow.

## Per-project config

Project root `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md", "docs/style.md"],
  "agent": {
    "build": { "model": "anthropic/claude-sonnet-4-5" }
  }
}
```

Deep-merges over global. Good for project-specific rules, different models.

## AGENTS.md hierarchy

- Global: `~/.config/opencode/AGENTS.md` — loaded via `instructions` in opencode.json
- Project: `./AGENTS.md` — auto-loaded if present

Both apply. Project can override/expand.

## Keybinds

TUI keybinds customizable in `tui.json`. Defaults:

- Tab: switch primary agent
- `:q` or `ctrl+q`: quit
- `@`: mention agent/file
- `/`: command list

## Web / Serve

```bash
opencode web # open web UI
opencode serve --port 4096 # headless server
```

Useful for remote or IDE integration.

## Cost control

- Set `agent.<name>.steps` to limit iterations
- Use `small_model` for light tasks
- Disable `snapshot` if disk hungry (saves .git-like tracking)
- Check `opencode stats` for token usage

## Common pitfalls

- Don't use `OPENCODE_CONFIG` to point to broken JSON — opencode hard-fails on invalid config. Use `OPENCODE_DISABLE_PROJECT_CONFIG=1` to bypass broken project config, or `OPENCODE_PURE=1` to skip plugins.
- Don't commit secrets — use `{env:VAR}` or `{file:path}` in config
- Don't create throwaway scripts in repo — use `/tmp` or delete after
