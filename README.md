# opencode-autonomy

High-autonomy config for [opencode](https://opencode.ai) — one obvious way to ship.

> "This file is the complete algorithm. Everything else is just efficiency." — Karpathy

**The algorithm** (3 steps):
1. One primary agent (`build`) that makes reasonable assumptions, batches 3-5 edits, verifies with evidence.
2. One fixer subagent that closes the loop: lint → type → test → build → fix → rerun.
3. One command `/ship` that runs concept → plan → implement → verify → fix → report.

## Model strategy — 5 models, 5 families

One strong default does 80% of work. Subagents are cheap and different to catch blind spots. No duplicate models with different knobs.

- `meta/muse-spark-1.1` (Meta, custom API) → `build` primary, 300 steps, 1M context, reasoning — does 80%
- `openrouter/google/gemini-flash-latest` (Google) → `small_model`, cheap title/summary
- `openrouter/anthropic/claude-sonnet-4-5` (Anthropic) → `fixer`, strong repair
- `openrouter/qwen/qwen3-coder` (Qwen) → `explore`, code search specialist
- `openrouter/openai/gpt-4o-mini` (OpenAI) → `plan`, cheap planning with different blind spot

Providers: `meta` via `{file:~/.config/opencode/meta-api-key}` (custom API), `openrouter` via `{env:OPENROUTER_API_KEY}`. Two keys, five families.

## Install (trivial, verifiable)

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
./install.sh --clean   # exact sync, removes stale files, prunes backups to 3
# or: ./install.sh     # merge mode (keeps your custom files)
opencode debug config  # must pass
```

## Try it

```bash
/ship Implement markdown preview with live reload
/fix Settings crashes when email empty
```

- Tab cycles: `build` (meta/spark) ↔ `plan` (openai/gpt-4o-mini)
- `@explore` (qwen coder) parallel search, `@fixer` (anthropic sonnet) explicit fix

## What you get

```
agents/
  build.md    → primary, 300 steps, meta/muse-spark-1.1, ships end-to-end
  fixer.md    → subagent, anthropic sonnet, closes lint/type/test loop

commands/
  ship.md     → closed-loop: concept → plan → batch implement → verify → fix → report
  fix.md      → quick repair with verification loop

opencode.json.example → 5 models: meta strong default + 4 openrouter specialists (google flash, anthropic sonnet, qwen coder, openai mini)
scripts/detect-oracle.sh → infers oracle commands from package.json/Makefile
```

3 files to understand: `README.md`, `opencode.json.example`, `commands/ship.md` — <5 min.

## Config

`opencode.json.example` is canonical. Install merges autonomy keys into your existing config, preserving your `model` and `provider`.

Core tuning:
- `subagent_depth: 3` → allows `build → explore → fixer` chains
- `formatter + lsp: true` → auto-fix formatting, type diagnostics
- `permission: allow all` → zero interruptions
- `tool_output: 5000 lines / 200KB` → full logs for fix loop
- `compaction.tail_turns: 12` → long session survival
- `batch_tool: true` → parallel discovery + edits

Docs: https://opencode.ai/docs

## One-shot prompt for opencode

```
You are implementing vocino/opencode-autonomy clean:
1. rm -rf /tmp/opencode-autonomy
2. git clone https://github.com/vocino/opencode-autonomy.git /tmp/opencode-autonomy
3. cd /tmp/opencode-autonomy && ./install.sh --clean
4. Verify: agents/ dest matches repo agents/, opencode debug config passes, backups <=3
5. rm -rf /tmp/opencode-autonomy after success
```

## Verify

```bash
jq empty opencode.json.example
bash scripts/detect-oracle.sh
bash tests/validate.sh   # checks 5 distinct models, 5 families, no dup, smoke install
```

## License

MIT
