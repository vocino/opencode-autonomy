# opencode-autonomy

[![CI](https://github.com/vocino/opencode-autonomy/actions/workflows/ci.yml/badge.svg)](https://github.com/vocino/opencode-autonomy/actions/workflows/ci.yml)
[![npm version](https://img.shields.io/npm/v/opencode-autonomy.svg)](https://www.npmjs.com/package/opencode-autonomy)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

opencode config that actually ships. One command, no babysitting — concept to verified code with tests passing.

> "This file is the complete algorithm. Everything else is just efficiency." — Karpathy

Drop-in autonomy suite for [opencode.ai](https://opencode.ai). Two agents, two commands, one config, 5 models from 5 families, zero permission prompts. Installs via `opencode plugin` in seconds, optional `npx` asset sync, updates with one command.

If you use opencode and you're tired of hand-holding your AI, this is for you.

## ⚠️ Autonomy & Permissions — READ THIS

**This suite is intentionally opinionated for minimal user intervention.**

What it enables:

```
permission: {"*":"allow", "external_directory":"allow", "doom_loop":"allow"}
experimental.batch_tool=true, continue_loop_on_deny=true
tool_output: 5000 lines / 200KB, compaction tail 12, 1M context
subagent_depth=3, formatter + lsp + snapshot enabled
```

**What that means:**
- Agents **will** edit files, run `npm install`, `git`, `rm`, push code **without asking**.
- They batch 3-5 files, run lint → typecheck → test → build, hand failures to `@fixer`, loop until green or 3x same error.
- They do **not** pause to ask "should I continue?". That's the point — long tasks work autonomously.

**Risks & mitigations:**
- Risk: destructive bash in wrong dir. Mitigation: opencode snapshot is enabled, git status/diff checked before edits, backups of `opencode.json` kept (last 3).
- Risk: CI costs from loops. Mitigation: 300 steps max for build, 150 for fixer, 3x same-error stop condition.
- Safe mode: `Tab` to `plan` agent — it has `bash/edit/write = ask` and is read-only by default.
- Undo: `npx opencode-autonomy --disable` or `opencode-autonomy --disable` restores latest backup. Or remove `permission` override from opencode.json.

By installing you acknowledge you want allow-all autonomy. If that's not you, use `plan` primary or don't install.

## Quick start — plugin first (recommended)

About a minute, no git clone:

```bash
# opencode itself
curl -fsSL https://opencode.ai/install | bash

# keys — OpenRouter for 4 models, Meta file for Spark
export OPENROUTER_API_KEY="sk-or-..."
echo "your-meta-key" > ~/.config/opencode/meta-api-key

# install runtime plugin (global: all repos on this machine)
opencode plugin opencode-autonomy --global

# optional but nice: copy markdown agents/commands/scripts locally so you can edit them
npx opencode-autonomy@latest --clean

# validate
opencode debug config

# then
opencode
# inside: /ship Implement markdown preview with live reload
```

Update anytime:

```bash
# runtime plugin update (recommended)
opencode plugin opencode-autonomy@latest --global -f

# optional: refresh local markdown/script assets
npx opencode-autonomy@latest --clean
```

Global vs project scope:

- Use `--global` if you want this behavior everywhere on your machine.
- Omit `--global` inside a repo if you want autonomy only for that project.

What `npx opencode-autonomy` installs locally:

```
~/.config/opencode/
├── opencode.json          # merged — your model/provider preserved, autonomy keys forced
├── agents/
│   ├── build.md           # primary, 300 steps, ships end-to-end
│   └── fixer.md           # subagent that closes the loop on failures
├── commands/
│   ├── ship.md            # /ship — the full loop
│   └── fix.md             # /fix — quick repair
└── scripts/
    └── detect-oracle.sh   # finds your lint/type/test/build commands
```

## Install modes (best practice)

If you only run one command, run the global plugin install:

```bash
opencode plugin opencode-autonomy --global
```

That keeps autonomy defaults enforced at runtime every session.

**Optional add-ons**

**1) Local markdown assets (recommended for editable prompts)**

```bash
npx opencode-autonomy@latest --clean
```

This copies `agents/*.md`, `commands/*.md`, and `scripts/*.sh` into `~/.config/opencode` so prompts are local, readable, and editable.

**2) Version pinning (for reproducible setups)**

```bash
opencode plugin opencode-autonomy@0.2.3 --global -f
```

Use this when you want the exact same behavior across machines or teams.

**3) Project-scoped install (repo-only behavior)**

```bash
opencode plugin opencode-autonomy
```

Omit `--global` to install in the current project's opencode config instead of your user-wide config.

At startup, opencode will:

- `bun install` this package into `~/.cache/opencode/node_modules/`
- Run its `config` hook which **forces** `permission allow-all`, `tool_output` big, `batch_tool`, `subagent_depth=3`, etc.
- Injects `build/fixer/explore/plan` agents and `ship/fix` commands as JSON fallbacks if markdown not present.

Best experience is still **both**:

- `opencode plugin opencode-autonomy --global` for live enforcement
- `npx opencode-autonomy@latest --clean` for local markdown assets
- Updates: `opencode plugin opencode-autonomy@latest --global -f` (+ optional `npx ... --clean`)

## Legacy: git clone

Still supported:

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
./install.sh --clean
opencode debug config
```

Preserves model/provider, merges autonomy.

## Demo

Real session:

```
You: /ship Add dark mode toggle to settings, persist in localStorage

build: Concept — settings has no theme logic yet
       Plan — 4 steps: read settings, add toggle, persist, test
       Implement — 3 files batched:
         src/components/Settings.tsx
         src/hooks/useTheme.ts
         src/styles/theme.css
       Verify — lint ok, tsc ok, tests: 2 failed
       Fix — @fixer fixes missing import + null check, reruns
       Verify — lint ok, tsc ok, tests ok, build ok

       Changed: 3 files, toggle + hook + css vars
       Verified: 12 tests pass, build 89kB
       Commit: feat(settings): add dark mode toggle with localStorage
```

It doesn't ask you if it should continue. It just ships.

## Features

| Thing | Here | Most configs |
|-------|------|--------------|
| Permissions | `allow all`, never asks | Prompts for every edit |
| Edits | 3-5 files batched, then verified | One file at a time |
| Verification | lint -> typecheck -> test -> build -> auto-fix loop | Stops after first edit |
| Models | 5 models, 5 families, no duplicates | Single model, same blind spots |
| Fixing | fixer subagent repairs failures itself | You clean up after it |
| Context | 5000 lines, 200KB output, 1M context, tail 12 | Logs truncated |
| Install | `opencode plugin opencode-autonomy` (+ optional `npx` for local files) | git clone + manual |
| Updates | `opencode plugin opencode-autonomy@latest --global -f` (+ optional `npx ... --clean`) | git pull |

Model setup:

- `meta/muse-spark-1.1` — build primary, 300 steps, 1M context, does 80% of work
- `openrouter/google/gemini-flash-latest` — small_model, titles and summaries
- `openrouter/anthropic/claude-sonnet-4-5` — fixer, repairs broken builds
- `openrouter/qwen/qwen3-coder` — explore, parallel code search
- `openrouter/openai/gpt-4o-mini` — plan, cheap planning with different blind spots

Two keys, five families. The point is diversity, not 15 agents you can't keep track of.

## Why this exists

I tried a bunch of high-autonomy configs. They were all either:

- too chatty — asking for permission to run `npm install`
- too fragile — no verification, green on their file but red tests everywhere else
- too single-model — one model doing everything, same mistakes over and over
- too complex — 15 agents, 20 commands, nobody knows what actually runs

The loop is actually simple: parse intent, plan if needed, batch edits, run checks, fix, report. Everything else is overhead.

This repo is 3 files you can read in 5 minutes: `README.md`, `opencode.json.example`, `commands/ship.md`. I built it on a CachyOS gaming + local-AI box that can't afford to break Steam or koboldcpp, so it's deliberately small and verifiable.

## Usage

**1. Ship a feature end-to-end**

Inside opencode:

```
/ship Implement user registration with email verification, form validation, onboarding flow
```

Build will scan `package.json` and existing patterns, write a short todo list (one in progress at a time), batch edit components/hooks/routes/tests, run whatever your repo uses for lint/type/test/build (detected automatically), hand failures to fixer, loop until green, then give you a report with what changed and a commit message ready.

**2. Fix something quick**

```
/fix Settings crashes when email is empty — TypeError in validateEmail
```

It searches for usages in parallel with `@explore`, checks git diff for context, patches the null check, runs tests, loops if needed.

**3. Search and plan**

```
@explore Find all API endpoints touching user creation and their auth middleware
```

Tab cycles `build` (Spark) and `plan` (gpt-4o-mini). Plan is read-only and asks before editing — good for checking approach before you burn steps. Build has full autonomy.

## How it works

```
/ship "goal"
  -> Concept: read repo, package.json, git status -> concrete outcome
  -> Plan: TodoWrite if 3+ steps, one active at a time
  -> Implement: batch 3-5 files, @explore in parallel for search
  -> Verify: detect-oracle.sh -> lint/type/test/build, capture evidence
  -> Fix: failures -> @fixer, rerun until green or 3x same error
  -> Ship: report changes, verification, commit message
```

Key bits in `opencode.json.example` and `src/autonomy.ts`:

- `subagent_depth: 3` lets `build -> explore -> fixer` chains happen
- `formatter + lsp: true` auto-fixes formatting and surface types
- `permission: allow all` for build, ask-mode for plan — **flagged in this README and CLI**
- `tool_output: 5000 lines / 200KB` so fix loops have full logs
- `compaction.tail_turns: 12` keeps long sessions alive
- `batch_tool: true` for parallel reads/edits

Plugin implementation (`src/plugin.ts`):

- Single source of truth: `src/autonomy.ts` defines autonomy config
- v1 plugin `config` hook forces autonomy keys, preserves your `model/provider`
- v2 `define` wrapper for future compat
- CLI `bin/cli.mjs` zero-deps ESM, works via `npx`, `npm -g`, or git clone

Opencode docs: https://opencode.ai/docs

## Roadmap

- [x] 5 models, 5 families, zero duplication
- [x] bloat-free installer with --clean and backup pruning
- [x] CI that actually validates config
- [x] **npx installable**: `npx opencode-autonomy@latest --clean`
- [x] **opencode plugin**: `plugin: ["opencode-autonomy"]` runtime enforcement
- [x] **autonomy warning flagged** in README + CLI
- [ ] example walkthroughs for Next.js and FastAPI repos
- [ ] real session recording (asciinema)
- [ ] benchmark: time-to-green vs vanilla opencode
- [ ] presets: minimal (2 models), max (add Grok/DeepSeek)

If you have an idea, open an issue. I read them.

## Development

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
npm install
npm run build          # tsc -> dist/
npm test               # bash tests/validate.sh
npx tsc --noEmit       # typecheck

# test npx locally
node ./bin/cli.mjs --dry-run
npm pack --dry-run     # check files included
XDG_CONFIG_HOME=/tmp/test ./bin/cli.mjs --clean
```

Structure:

```
.
├── agents/           # markdown agent definitions (bundled in npm)
├── commands/         # /ship, /fix markdown (bundled)
├── scripts/          # detect-oracle.sh
├── src/
│   ├── autonomy.ts   # single source of truth for autonomy config
│   ├── templates.ts  # asset reader
│   ├── plugin.ts     # v1 plugin — config hook that forces autonomy
│   └── index.ts      # v2 wrapper + re-exports
├── bin/cli.mjs       # npx entry — zero deps, ESM
├── dist/             # built JS (published to npm)
├── opencode.json.example
├── package.json      # bin + exports . and ./plugin
└── tests/validate.sh
```

Publishing / Auto-update (maintainer):

This repo auto-publishes to npm via GitHub Actions + OIDC trusted publishing.

- Every push to `main` with conventional commits (e.g. `feat:`, `fix:`) triggers `release-please`
- Release-please opens/updates a Release PR that bumps `package.json` + `CHANGELOG.md`
- When that Release PR is merged, `release.yml` publishes to npm with provenance:
  `npm publish --provenance --access public`

**One-time setup for trusted publishing (no NPM_TOKEN needed):**

1. Go to https://www.npmjs.com/package/opencode-autonomy/access
2. Trusted Publishers → Add GitHub Actions:
   - Repo: `vocino/opencode-autonomy`
   - Workflow: `release.yml` (and also `publish-tag.yml` for manual tags)
   - Environment: leave empty
3. Ensure workflows have `id-token: write` (already set)

Fallback:

```bash
# Manual tag publish (workflow publish-tag.yml)
npm version patch # or minor/major
git push --follow-tags

# Or manual local publish
npm run build
npm publish --access public
```

Users then update via:

```bash
# runtime plugin update
opencode plugin opencode-autonomy@latest --global -f

# optional: refresh local markdown/script assets
npx opencode-autonomy@latest --clean
```

## Contributing

PRs welcome. Goal is to keep it the obvious way to ship, not to add more stuff.

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
bash tests/validate.sh   # must pass
```

I care about:

- simplicity — 2 agents, 2 commands is intentional, don't add a third unless you can justify it
- 5 models, 5 families, 0 duplicates
- verifiable — `opencode debug config` and the smoke install test must pass
- no bloat — no extra deps runtime, only dev deps for types
- autonomy-first — minimal intervention, long tasks just ship

Before you open a PR:

- `bash tests/validate.sh` passes
- `jq empty opencode.json.example` passes
- `npx tsc -p tsconfig.json --noEmit` passes
- `shellcheck` on any changed shell scripts
- no keys or secrets — `*.key`, `auth.json` are gitignored

Ideas that would help: better oracle detection for Rust/Go/Python, clearer errors in install.sh, example repos showing /ship working.

## License

MIT — see LICENSE.
