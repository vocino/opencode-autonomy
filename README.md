# opencode-autonomy

High-autonomy config for [opencode](https://opencode.ai) — one obvious way to ship.

> "This file is the complete algorithm. Everything else is just efficiency." — Karpathy

**The algorithm** (3 steps):
1. One primary agent (`build`) that makes reasonable assumptions, batches 3-5 edits, verifies with evidence.
2. One fixer subagent that closes the loop: lint → type → test → build → fix → rerun.
3. One command `/ship` that runs concept → plan → implement → verify → fix → report.

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

- Tab cycles agents: `build` (primary) ↔ `plan` (read-only, built-in)
- `@explore` parallel search, `@fixer` explicit fix delegation

## What you get

```
agents/
  build.md    → primary, 300 steps, ships end-to-end
  fixer.md    → subagent, closes lint/type/test loop

commands/
  ship.md     → closed-loop: concept → plan → batch implement → verify → fix → report
  fix.md      → quick repair with verification loop

opencode.json.example → 8 keys that matter: subagent_depth=3, formatter, lsp, permission=allow, batch_tool, tool_output 5k/200k, compaction tail 12, agent steps

scripts/detect-oracle.sh → infers oracle commands from package.json/Makefile
```

3 files to understand system: `README.md`, `opencode.json.example`, `commands/ship.md` — <5 min.

## Config

`opencode.json.example` is canonical. Install merges it into your existing `~/.config/opencode/opencode.json`, preserving your `model` and `provider` keys.

Core tuning:
- `subagent_depth: 3` → allows `build → explore → fixer` chains
- `formatter + lsp: true` → auto-fix formatting, type diagnostics
- `permission: allow all` → zero interruptions
- `tool_output: 5000 lines / 200KB` → full logs for fix loop
- `compaction.tail_turns: 12` → long session survival
- `batch_tool: true` → parallel discovery + edits

Set `OPENROUTER_API_KEY` or edit `model` in config. Docs: https://opencode.ai/docs

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
bash tests/validate.sh
```

## License

MIT
