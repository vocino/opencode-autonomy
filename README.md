# opencode-autonomy

[![CI](https://github.com/vocino/opencode-autonomy/actions/workflows/ci.yml/badge.svg)](https://github.com/vocino/opencode-autonomy/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![opencode](https://img.shields.io/badge/powered%20by-opencode-black)](https://opencode.ai)
[![GitHub stars](https://img.shields.io/github/stars/vocino/opencode-autonomy?style=social)](https://github.com/vocino/opencode-autonomy/stargazers)

### One command to ship. No hand-holding.

**High-autonomy config for [opencode](https://opencode.ai) — your AI agent that actually finishes the job end-to-end: concept → plan → batch implement → verify → fix → report.**

> "This file is the complete algorithm. Everything else is just efficiency." — Karpathy

---

### What is this? Who is it for? What problem does it solve?

**opencode-autonomy** is a drop-in configuration pack for [opencode.ai](https://opencode.ai) that turns it into a fully autonomous coding agent.

- **What:** 2 agents, 2 commands, 1 config — 5 models across 5 families working together. Zero interruptions.
- **Who:** Developers who use opencode and are tired of babysitting AI agents that stop after 1 file, ask permission for obvious fixes, or leave tests red.
- **Problem:** Most agent setups are high-friction: they pause to ask "should I continue?", edit one file at a time, and skip verification. This config ships the whole way — with evidence.

If you've said "just ship it" and the agent said "what do you mean?" — this is for you.

---

### ⚡ Quick Start — under 60 seconds

```bash
# 1. Install opencode if you haven't (https://opencode.ai)
curl -fsSL https://opencode.ai/install | bash

# 2. Set two keys (you need OpenRouter, and a Meta API key for Spark — see docs)
export OPENROUTER_API_KEY="sk-or-..."
echo "your-meta-key" > ~/.config/opencode/meta-api-key

# 3. Clone and install this config
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
./install.sh --clean

# 4. Verify
opencode debug config   # must pass
bash tests/validate.sh  # 5 models, 5 families, smoke test

# 5. Ship something
opencode
# then inside opencode: /ship Implement a markdown preview with live reload
```

That's it. You're autonomous.

---

### 📦 Install

**Recommended — clean sync (exact replica, removes stale files):**

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
./install.sh --clean
opencode debug config
```

**Merge mode — keeps your customizations:**

```bash
./install.sh
# merges autonomy keys (agents, permissions, tool output limits)
# preserves your model and provider settings
```

**What gets installed:**

```
~/.config/opencode/
├── opencode.json          ← merged (your model/provider preserved)
├── agents/
│   ├── build.md           ← primary, 300 steps, ships end-to-end
│   └── fixer.md           ← subagent, closes lint/type/test loop
├── commands/
│   ├── ship.md            ← /ship — the closed loop
│   └── fix.md             ← /fix — quick repair
└── scripts/
    └── detect-oracle.sh   ← auto-detects lint/type/test/build
```

**Requirements:**
- [opencode](https://opencode.ai) installed
- `OPENROUTER_API_KEY` env var (for 4 specialist models)
- `~/.config/opencode/meta-api-key` file (for Meta Spark primary)
- `jq` (for config merge/validation)

> Backup safety: install creates timestamped backups `opencode.json.bak.<ts>` and prunes to 3 in `--clean` mode.

---

### 🎬 Demo — How it feels

```
You: /ship Add dark mode toggle to settings, persist in localStorage

build:  Concept → settings has no theme, needs toggle + persistence
        Plan → 4 steps: 1) read settings 2) add toggle 3) persist 4) test
        Implement → batched 3 files:
          - src/components/Settings.tsx (toggle UI)
          - src/hooks/useTheme.ts (localStorage logic)
          - src/styles/theme.css (variables)
        Verify → npm run lint ✓, tsc ✓, npm test 2 failed
        Fix → @fixer: missing import + null check → rerun
        Verify → lint ✓, tsc ✓, test ✓, build ✓
        Ship →

        What changed: 3 files, toggle + hook + css vars, why: requirement
        Verified: lint ok, typecheck ok, 12 tests pass, build 89kB
        Commit: feat(settings): add dark mode toggle with localStorage persistence
```

No "should I continue?". No half-done PR. Just shipped.

---

### ✨ Features — what makes this different

| Feature | This config | Typical setup |
|---------|-------------|---------------|
| **Autonomy** | `permission: allow all`, never asks | Asks for every edit |
| **Batching** | 3-5 files at once, then verify | 1 file at a time |
| **Verification loop** | lint → type → test → build → fix → rerun | Stops at first green file |
| **Model diversity** | 5 models, 5 families, no dupes | 1 model, same blind spots |
| **Fixer subagent** | Anthropic Sonnet repairs automatically | You fix agent's breakage |
| **Long sessions** | 5000 lines output, tail 12, 1M context | Truncated logs, lost context |
| **Install** | One script, verifiable, merge-safe | Copy-paste docs |

**5 models, 5 families — one strong default:**

- `meta/muse-spark-1.1` (Meta) → `build` primary, 300 steps, 1M context, reasoning — does 80%
- `openrouter/google/gemini-flash-latest` (Google) → `small_model`, cheap title/summary
- `openrouter/anthropic/claude-sonnet-4-5` (Anthropic) → `fixer`, strong repair
- `openrouter/qwen/qwen3-coder` (Qwen) → `explore`, parallel code search specialist
- `openrouter/openai/gpt-4o-mini` (OpenAI) → `plan`, cheap planning with different blind spot

Two keys, five families. No duplicate models with different knobs.

---

### 💡 Why this exists

I tried high-autonomy configs for opencode. Most were either:

1. **Too chatty** — asking permission for `npm install` or a missing import
2. **Too fragile** — no verification, left tests red, no fix loop
3. **Too single-model** — same blind spots, no cheap/expensive split
4. **Too complex** — 15 agents, 20 commands, no one knows what runs

The Karpathy quote says it all: the algorithm is simple. Parse → plan → batch implement → verify → fix. Everything else is efficiency.

This repo distills it to **3 files you can read in <5 minutes**: `README.md`, `opencode.json.example`, `commands/ship.md`. The rest is tooling.

Built for a CachyOS gaming + local-AI desktop that must never break Steam/Proton or koboldcpp — so it's bloat-free, verifiable, and fast.

---

### 🚀 Real Usage Examples

**1. Ship a new feature — end-to-end**

```bash
# Inside opencode:
/ship Implement user registration with email verification, form validation, and onboarding flow

# Build will:
# - Scan package.json, existing auth patterns, AGENTS.md
# - TodoWrite 8 steps (ONE in_progress)
# - Batch edit 4 files: components, hook, api route, test
# - Run: npm run lint, tsc --noEmit, npm test, npm run build
# - Fix failures via @fixer, rerun until green
# - Report: what changed, what verified, commit message ready
```

**2. Quick fix with verification loop**

```bash
/fix Settings crashes when email is empty — TypeError in validateEmail

# Build will:
# - @explore for validateEmail usages (parallel)
# - Check git diff, recent changes
# - Batch fix null check + test
# - Verify loop: test red → fix → green
# - Report final status
```

**3. Parallel exploration + cheap planning**

```bash
# Use subagents explicitly for speed:
@explore Find all API endpoints that touch user creation, include auth middleware

# Tab cycles: build (meta/spark) ↔ plan (gpt-4o-mini)
# plan proposes approach (read-only, asks before edits)
# build executes with full autonomy
```

---

### ⚙️ How it works

```
┌─────────────────────────────────────────────────────────┐
│  /ship "goal"                                           │
│    │                                                    │
│    ├─ Concept: Scan repo, package.json, git status      │
│    │         → concrete outcome + constraints           │
│    │                                                    │
│    ├─ Plan: TodoWrite if 3+ steps (ONE in_progress)     │
│    │                                                    │
│    ├─ Implement: Batch 3-5 files, follow patterns       │
│    │   ├─ @explore (qwen) parallel search               │
│    │   └─ build (spark) ships                          │
│    │                                                    │
│    ├─ Verify: detect-oracle.sh → lint/type/test/build   │
│    │   └─ capture exit code + evidence                 │
│    │                                                    │
│    ├─ Fix: Failures → @fixer (sonnet) loop until green  │
│    │   └─ or 3x same error → report & stop              │
│    │                                                    │
│    └─ Ship: What changed, verified, human input, commit │
└─────────────────────────────────────────────────────────┘
```

**Core tuning in `opencode.json.example`:**

- `subagent_depth: 3` — allows `build → explore → fixer` chains
- `formatter + lsp: true` — auto-fix formatting, type diagnostics
- `permission: allow all` — zero interruptions (plan agent is ask-mode for safety)
- `tool_output: 5000 lines / 200KB` — full logs for fix loop
- `compaction.tail_turns: 12` — long session survival (300 steps need it)
- `batch_tool: true` — parallel discovery + edits

Docs: https://opencode.ai/docs

---

### 🗺️ Roadmap

- [x] 5-model strategy, 5 families, no duplication
- [x] Bloat-free installer with `--clean` and backup pruning
- [x] CI validation + `detect-oracle.sh`
- [ ] Example repos showing `/ship` in the wild (Next.js, Python FastAPI)
- [ ] `opencode-autonomy` as installable plugin via `opencode registry`
- [ ] Recording of real session (demo GIF / asciinema)
- [ ] Benchmark: time-to-green for common tasks vs vanilla opencode
- [ ] Optional presets: `minimal` (2 models), `max` (add Grok, DeepSeek)

Have ideas? Open an issue or discussion.

---

### 🤝 Contributing

Contributions welcome — this is meant to be the obvious way to ship.

**Quick start for contributors:**

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
bash tests/validate.sh   # must pass before PR
```

**What we look for:**

- Keeps it simple: 2 agents, 2 commands is intentional. Prove need before adding.
- 5 models, 5 families, 0 duplicates — preserve diversity.
- Verifiable: `opencode debug config` must pass, install smoke test must pass.
- Bloat-free: no extra deps, no opaque scripts.

**PR checklist:**

- [ ] `bash tests/validate.sh` passes
- [ ] `jq empty opencode.json.example` passes
- [ ] `shellcheck` on changed `.sh` files
- [ ] Updated README if user-facing behavior changed
- [ ] No secrets committed (`*.key`, `auth.json` are gitignored)

**Good first issues:**

- Add language-specific oracle detection (Rust, Go, Python already partial)
- Improve error messages in `install.sh`
- Write example walkthroughs for popular stacks

---

### 📄 License

MIT — see [LICENSE](LICENSE). Free for any use, attribution appreciated.

---

<p align="center">
Built for shipping. Not for chatting.<br>
<strong>/ship it</strong>
</p>
