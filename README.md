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

### Copy-paste prompt — keeps your models

Paste this into opencode (preferred — it understands your current config):

```
Install the opencode-autonomy plugin from https://github.com/vocino/opencode-autonomy — keep my existing models, providers, and apiKeys in opencode.json. Only set model/small_model/agent model if I don't already have one. Merge autonomy agents (build, build-worker, fixer, explore, plan, council-critic, council-creative) without overwriting my custom agent models. Add parallel build-worker lane support (same model as build). Preserve my provider baseURL/apiKey. Verify with opencode debug config.
```

You still get the power of different models (build + workers share 1M, fixer is sonar-ish, explore is qwen), but if you already pinned `build` to claude-sonnet or your own meta key, it stays yours. New users get the 5-model defaults.

### Shell install — also preserves models

Same merge logic now lives in the CLI:

```bash
opencode plugin opencode-autonomy --global
npx opencode-autonomy@latest --clean   # copies agents/ + merges opencode.json without nuking your models
```

Verify:

```bash
opencode debug config
agents list   # should show build, build-worker, fixer, explore, plan
```

If you *want* our defaults, just delete `~/.config/opencode/opencode.json` and re-run `npx` — you'll get the full 5-model suite.


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
- `commands/ship.md` — the whole loop, parallel-aware
- `agents/build.md` — orchestrator, parallel lane detection + fan-out
- `agents/build-worker.md` — same-model workers, one per lane
- `agents/fixer.md`, `agents/explore.md`, council agents — minimal set
- `src/autonomy.ts` — single source of truth for forced keys
- `src/plugin.ts` — v1 config hook, preserves your model/provider
- `bin/cli.mjs` — zero-dep npx installer

Why 5 models, 5 families (build + workers share meta):

- `meta/muse-spark-1.2-contributor` — build orchestrator + build-worker lanes, 1M, 80% of work
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
  -> Plan: TodoWrite if 3+ steps + annotate parallel lanes (disjoint file sets)
  -> Implement: parallel via @build-worker (same model, 2-3x faster) OR sequential batch 3-5 files
  -> Merge: collect lane summaries (no file overlap)
  -> Verify: detect-oracle.sh → lint/type/test/build
  -> Fix: @fixer per failing lane, parallel if disjoint
  -> Ship: report + parallelism used + commit msg
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
