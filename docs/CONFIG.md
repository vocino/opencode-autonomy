# Config Deep Dive — opencode-autonomy

This doc explains every high-autonomy tuning key in `opencode.json.example` and why it matters.

## Core

### `model` / `small_model`
- `model`: your main heavy reasoning model. Example: `anthropic/claude-sonnet-4-5`, `meta/muse-spark-1.1`, `cursor/composer-2.5`.
- `small_model`: fast/cheap model for lightweight tasks like title generation, summary. Example: `cursor/claude-haiku-4-5`, `anthropic/claude-haiku-4-5`, `openrouter/google/gemini-flash-latest`. Speeds up session start / compaction.

### `default_agent`
Set to `build` — our high-autonomy primary. Must be primary mode agent.

### `subagent_depth`
- Default: 1 (primary can launch subagent, but subagent cannot launch its own subagent).
- Autonomy: **3** — enables chains like `build → explore → general → fixer`. Critical for parallel discovery + delegation without blocking primary context.

### `snapshot: true`
Enables filesystem snapshot tracking. Allows undo/redo in TUI (`/undo`, `/redo`). Slight overhead on large repos but worth for safety. Disable only if repo is huge and indexing is slow.

## Tooling

### `formatter: true`
Enables built-in formatters (prettier, etc.). Opencode auto-formats on save if formatter available. Reduces manual lint fixes during autonomous runs.

### `lsp: true`
Enables LSP servers (typescript, etc.). Gives type diagnostics, go-to-def, auto-imports. Autonomous agent can check diagnostics instead of guessing.

### `tool_output`
```json
{
  "max_lines": 5000,
  "max_bytes": 204800
}
```
Default: 2000 lines / 51200 bytes. Raised 2.5x / 4x to avoid truncation on long test runs. Full logs needed for autonomous fix loops.

## Compaction

```json
{
  "auto": true,
  "tail_turns": 12,
  "prune": false,
  "reserved": 20000,
  "preserve_recent_tokens": 20000
}
```
- `auto: true` — auto compact when context full
- `tail_turns: 12` — keep last 12 user turns verbatim (default 2). Critical for long tasks — preserves recent edits + errors.
- `prune: false` — don't prune old tool outputs aggressively; keep history for debugging.
- `reserved: 20000` — token buffer during compaction to avoid overflow.
- `preserve_recent_tokens: 20000` — keep up to 20k recent tokens verbatim after compaction.

## Watcher

```json
{
  "ignore": ["node_modules/**", "dist/**", "build/**", ".next/**", ".git/**", "target/**", ".cache/**", "__pycache__/**", ".venv/**", "coverage/**"]
}
```
File watcher ignores noisy dirs. Prevents constant re-indexing during `npm install` or builds.

## Experimental

### `batch_tool: true`
Enables batch tool execution — agent can run 5+ tools in parallel in one turn. Massive speed-up for discovery (`glob` + `grep` + `read` in parallel) and batched edits.

### `continue_loop_on_deny: true`
If a tool call is denied by permission, continue loop instead of stopping. Resilience for autonomy.

### `primary_tools`
Optional array of tools only available to primary agents. Not used here — we allow all.

## Permissions

```json
{
  "*": "allow",
  "external_directory": "allow",
  "doom_loop": "allow"
}
```

Goal: zero interruptions. `* allow` covers all regular tools (bash, edit, read, glob, grep, webfetch, skill, question, etc).

- `* allow` — base allow all regular tools
- `external_directory allow` — allow reading/writing outside worktree (default is ask). Needed for monorepos, ~/.config access, shared templates.
- `doom_loop allow` — allow recovery prompts when agent appears stuck (same tool 3x). Don't block loop recovery.

Optional if you use opencode-cursor plugin:
```json
{ "cursor_delegate": "allow", "cursor_cloud_agent": "allow" }
```

### Per-agent overrides

- `build` / `autonomous` / `ultrawork` / `specifier` / `fixer` inherit global `* allow` (no per-agent override needed).
- `plan` has `bash: ask`, `edit: ask`, `write: ask` — read-only analysis, safe.
- `reviewer` has `edit: deny`, `rm`/`mkfs` deny — truly read-only + safe.

## Agent tuning

### `steps`
Maximum agentic iterations before forcing text-only response. Controls cost / max work.

- `build: 200` — solid for most features + fix loop
- `autonomous: 300` — closed-loop SHIP (concept -> spec -> plan -> decompose -> implement -> verify -> fix -> ship)
- `ultrawork: 400` — entire projects, migrations, large refactors
- `specifier: 120` — concept/spec/DoD artifact authoring
- `fixer: 150` — enough for multi-file lint/type/test loops
- `reviewer: 80` — enough for thorough review
- `plan: 100` — analysis doesn't need huge steps

When limit reached, agent gets system prompt to summarize work + remaining tasks.

### `temperature`
- 0.1-0.2 for focused deterministic (build, autonomous, fixer, reviewer)
- 0.25 for slightly more creative (ultrawork)
- Higher (0.6+) for brainstorming — not needed here.

## Provider config (user-specific)

In example we show:

```json
"provider": {
  "anthropic": {
    "options": { "apiKey": "{env:ANTHROPIC_API_KEY}" }
  }
}
```

Supported substitutions:
- `{env:VAR}` — env var
- `{file:path}` — file content (e.g., `~/.config/opencode/anthropic.key`)

Keep secrets out of repo. Use direnv `.envrc` or key files with 600 perms.

## Minimal patch

If you already have a config and just want autonomy, merge `opencode.json.minimal.example`:

```json
{
  "small_model": "anthropic/claude-haiku-4-5",
  "subagent_depth": 3,
  "snapshot": true,
  "formatter": true,
  "lsp": true,
  "tool_output": { "max_lines": 5000, "max_bytes": 204800 },
  "compaction": { "auto": true, "tail_turns": 12, "prune": false, "reserved": 20000, "preserve_recent_tokens": 20000 },
  "watcher": { "ignore": [...] },
  "experimental": { "batch_tool": true, "continue_loop_on_deny": true },
  "permission": { "*": "allow", "external_directory": "allow", "doom_loop": "allow" },
  "agent": { "build": { "mode": "primary", "steps": 200, "temperature": 0.2 } }
}
```

Then `opencode debug config` to validate.

## Install merge behavior

`install.sh` merges from `opencode.json.example` with these goals:

- Preserve user-selected `model` and provider credentials
- Overwrite autonomy tuning keys (`subagent_depth`, `tool_output`, `compaction`, `formatter`, `lsp`, `experimental`, `permission`)
- Merge `instructions` arrays so `AGENTS.md` stays installed
- Merge agent metadata so closed-loop agents (`autonomous`, `specifier`) are available
