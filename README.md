# opencode-autonomy

Actually ships. One command, no babysitting — concept to verified code.

## Problem

Most opencode configs are:

- too chatty — asks to run `npm install`
- too fragile — no verification, breaks tests
- too single-model — same blind spots
- too complex — 15 agents, no one knows what runs

You end up cleaning up after it.

## How to install

The easiest way — paste this into opencode, ChatGPT, Claude Code, Codex:

```
Install the opencode-autonomy plugin globally from https://github.com/vocino/opencode-autonomy
```

Or in your shell:

```bash
opencode plugin opencode-autonomy --global
npx opencode-autonomy@latest --clean   # optional local md assets you can edit
```

Verify:

```bash
opencode debug config
```

## How to use

### Ship a feature

```
/ship Add dark mode toggle, persist in localStorage
```

Scans repo, plans 3-5 file batches, runs lint → typecheck → test → build, hands failures to `@fixer`, loops until green.

### Fix

```
/fix Settings crashes when email empty
```

Parallel search with `@explore`, patches, reruns checks.

### Explore

```
@explore Find all API endpoints touching user creation
```

`Tab` to `plan` = read-only, asks first. Good for dry runs.

## Autonomy & Permissions — READ THIS

This is allow-all autonomy. Be aware.

```
permission: {"*":"allow", "external_directory":"allow", "doom_loop":"allow"}
batch_tool, 300 step build, 150 step fixer, 3x same-error stop
5000 lines / 200KB logs, tail 12, subagent_depth 3
```

ALLOW = allow all with `"*":"allow"` — full disk + bash + external dirs.
Adds `plugin: ["opencode-autonomy"]` at runtime, keeps your model/provider.

What happens:

- edits, `npm install`, `git`, `rm` without asking
- batches 3-5 files then verifies
- no "should I continue?" — that's the point

Undo: `npx opencode-autonomy --disable` restores backup of `opencode.json`.

If that's not you, use `plan` agent or don't install.

## What's inside

- `opencode.json.example` — full config, readable in 5 minutes
- `commands/ship.md` — the whole loop
- `agents/build.md` + `agents/fixer.md` — 2 agents, not 15
- `src/autonomy.ts` — single source of truth for forced keys
- `src/plugin.ts` — v1 config hook, preserves your model/provider
- `bin/cli.mjs` — zero-dep npx installer

Why 5 models, 5 families:

- `meta/muse-spark-1.1` — build, 1M, 80% of work
- `openrouter/google/gemini-flash-latest` — titles
- `openrouter/anthropic/claude-sonnet-4-5` — fixer
- `openrouter/qwen/qwen3-coder` — explore
- `openrouter/openai/gpt-4o-mini` — plan

Two keys, different blind spots. Built on CachyOS / Arch gaming box — small and verifiable.

## Install modes

```bash
# everywhere (recommended)
opencode plugin opencode-autonomy --global

# this repo only
opencode plugin opencode-autonomy

# pin version
opencode plugin opencode-autonomy@0.4.0 --global -f

# local markdown you can edit
npx opencode-autonomy@latest --clean
```

Updates: `opencode plugin opencode-autonomy@latest --global -f`

## How it works

```
/ship "goal"
  -> Concept: read repo + git status
  -> Plan: TodoWrite if 3+ steps
  -> Implement: batch 3-5 files, @explore parallel
  -> Verify: detect-oracle.sh → lint/type/test/build
  -> Fix: @fixer until green
  -> Ship: report + commit msg
```

`detect-oracle.sh` finds your checks from `package.json`.

## Ecosystem

- [opencode-ambient](https://github.com/vocino/opencode-ambient) — see tokens and money as light in your room
- Install both: autonomy drives, ambient glows

Using opencode on Arch Linux.

## Development

```bash
git clone https://github.com/vocino/opencode-autonomy.git
npm install && npm run build && npm test
```

## License

MIT
