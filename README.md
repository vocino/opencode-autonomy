# opencode-autonomy

High-autonomy OpenCode configuration — maximize independent progress, minimize back-and-forth. Turns vague ideas into working, tested, lint-clean implementations without stopping.

## 🚀 One-Shot Prompt — copy/paste to your opencode

```
Clone https://github.com/vocino/opencode-autonomy.git to /tmp/opencode-autonomy
and implement it: run ./install.sh logic (backup opencode.json → .bak.<ts>, merge
autonomy keys from opencode.json.example, copy agents/*.md and commands/*.md,
install AGENTS.md.example if missing), validate with `opencode debug config`,
adapt to my OS/shell/tooling. Report what changed + what verified, note
assumptions, remind to restart opencode. Do NOT commit secrets.
```

**Already cloned?** Just `/ship Implement this repo for my setup: ./install.sh + validate`

`install.sh` is canonical — the prompt above just points to it so it never drifts.

## What this is

A drop-in high-autonomy setup for [opencode](https://opencode.ai):

- **Core config** tuned for long autonomous runs
- **6 custom agents** (`build`, `autonomous`, `ultrawork`, `specifier`, `fixer`, `reviewer`)
- **6 commands** (`/ship`, `/verify`, `/autofix`, `/ultrawork`, `/fix`, `/review`)
- **SHIP templates + oracle detector** (`templates/ship/*`, `scripts/detect-oracle.sh`)
- **AGENTS.md** template embodying high-autonomy workflow

### Philosophy

```
Make reasonable assumptions when obvious from repo (package.json, patterns) — don't ask.
Keep working through tests, lint, type errors — fix B if your change breaks it.
Batch 3-5 related files, then validate.
Don't request approval for ordinary choices (naming, file location, small refactors, missing imports).
Ask ONLY when blocked by ambiguity affecting correctness, safety, or scope.
Stop ONLY when complete+verified, true blocker, or looping same error 3x.
```

## Quick Start

### 1. Clone and install

```bash
git clone https://github.com/vocino/opencode-autonomy.git
cd opencode-autonomy
./install.sh
# or manually: see MANUAL INSTALL below
```

`install.sh` will:
- Backup existing `~/.config/opencode/opencode.json` → `opencode.json.bak.<timestamp>`
- Merge high-autonomy settings into your config (or create new), preserving your model/provider
- Copy agents to `~/.config/opencode/agents/`
- Copy commands to `~/.config/opencode/commands/`
- Copy templates to `~/.config/opencode/templates/`
- Copy helper scripts to `~/.config/opencode/scripts/`
- Copy `AGENTS.md.example` → `~/.config/opencode/AGENTS.md` if you don't have one

### 2. Restart opencode

```bash
# quit current session (ctrl+q / exit)
opencode
```

Config is loaded once at startup.

### 3. Try it

```bash
# Full autonomous feature
/ship Implement a markdown preview component with live reload

# Maximum persistence, 400 steps
/ultrawork Refactor auth to use JWT + refresh tokens, migrate DB, update tests

# Fix loop
/autofix

# Quick fix
/fix The settings page crashes when email is empty

# Review
/review
```

Tab cycles primary agents: `build` ↔ `autonomous` ↔ `ultrawork` ↔ `plan`

## What’s inside — Autonomy Tuning

| Setting | Default | Autonomy | Why |
|---------|---------|----------|-----|
| `subagent_depth` | 1 | **3** | Allows chaining `build → explore → general → fixer` |
| `agent.build.steps` | ~80 | **200** | Long runs without forcing text-only |
| `agent.autonomous.steps` | — | **300** | Full feature implementation |
| `agent.ultrawork.steps` | — | **400** | Entire project builds / migrations |
| `small_model` | none | `anthropic/claude-haiku-4-5` | Fast title/summary, cheap |
| `tool_output.max_lines` | 2000 | **5000** | Full test/lint logs |
| `tool_output.max_bytes` | 51200 | **204800** | Avoid truncation |
| `compaction.tail_turns` | 2 | **12** | Keep 12 recent turns verbatim for long sessions |
| `compaction.reserved` | ~10000 | **20000** | Token buffer for compaction |
| `formatter` | false | **true** | Auto-fix formatting during autonomous work |
| `lsp` | false | **true** | Type diagnostics, auto-fix imports |
| `experimental.batch_tool` | false | **true** | Parallel tool calls |
| `experimental.continue_loop_on_deny` | false | **true** | Keep looping if one tool denied |
| `permission.*` | allow (mostly) | **allow all** | Zero interruptions |
| `watcher.ignore` | [] | `node_modules/**, dist/**, ...` | Noisy dirs ignored |

### Core snippet

Full configs: `opencode.json.example` (annotated) and `opencode.json.minimal.example` (just autonomy keys). Minimal autonomy core:

```json
{
  "subagent_depth": 3,
  "snapshot": true,
  "formatter": true,
  "lsp": true,
  "permission": { "*": "allow", "external_directory": "allow", "doom_loop": "allow" },
  "agent": { "build": { "mode": "primary", "steps": 200 } }
}
```

## Agents

### `build` (primary, steps 200, temp 0.2) — default high-autonomy dev
Ships features end-to-end, fixes tests/lint/types autonomously. Makes reasonable assumptions, batches edits (5 files → validate), uses subagents liberally (`@explore`, `@general`). Final output: what changed, what verified, commit msg ready (does NOT commit).

### `autonomous` (primary, steps 300, temp 0.2) — ultra-high autonomy
Takes vague idea and runs a strict closed loop: **Concept → Spec → Plan → Decompose → Implement → Verify → Fix → Ship**. Uses persistent SHIP artifacts in `.opencode/state/ship/<run-id>/`, requires machine-checkable DoD, and only completes when oracle checks pass.

### `ultrawork` (primary, steps 400, temp 0.25) — maximum persistence
Alias for autonomous but 2x steps tolerance. Designed for full feature implementations, migrations, large refactors. Phases: deep discovery (parallel @explore), planning (5-15 todos), implementation (batched), verification loop, report.

### `specifier` (subagent, steps 120, temp 0.15) — concept/spec/DoD author
Builds SHIP artifacts from templates, grounding in repo context. Creates `01-spec.md` and `02-dod.md`, seeds oracle commands via `scripts/detect-oracle.sh`, and maps acceptance criteria to machine-checkable checks.

### `fixer` (subagent, steps 150, temp 0.1) — autofix loop
Given failing lint/type/tests, fixes them. Detects project type from package.json, batches fixes 3-5 files, reruns verification until green or 3x same error.

### `reviewer` (subagent, steps 80, temp 0.15) — read-only review
Strict review for bugs, security (injection/auth/data exposure), performance regressions, type safety, maintainability, test gaps. Uses `git diff`, reports critical/major/minor with file:line.

## Commands

All commands support `$ARGUMENTS` forwarding.

| Command | Agent | What it does |
|---------|-------|--------------|
| `/ship <task>` | autonomous | Full closed-loop SHIP flow: concept → spec → plan → decompose → implement → verify → fix → ship with artifact gates. **Main workhorse.** |
| `/verify [run-dir]` | fixer | Runs machine-checkable DoD verification by combining `scripts/detect-oracle.sh` with `02-dod.md` oracle commands and looping fixes until green. |
| `/autofix [scope]` | fixer | Auto-detect project (npm/uv), run lint → fix, types → fix, tests → fix, build → fix, loop until green. |
| `/ultrawork <task>` | ultrawork | 400-step deep discovery + 5-15 todos + batched edits + verification loop. Use for vague ideas, migrations. |
| `/fix <issue>` | build | Quick fix one issue with context awareness, batch related, verify. |
| `/review [files]` | reviewer | Read-only review of `git diff HEAD` or specified files. |

### SHIP run artifacts

`/ship` and `/verify` use persistent artifacts in `.opencode/state/ship/<run-id>/`:

- `01-spec.md` (from `templates/ship/SPEC.template.md`)
- `02-dod.md` (from `templates/ship/DOD.template.md`)
- `03-plan.md` through `08-ship-report.md` for execution, verification, and final report

This makes long autonomous runs stateful and compaction-safe.

## AGENTS.md

`AGENTS.md.example` is a generic high-autonomy template you can drop into any repo or `~/.config/opencode/AGENTS.md` for global rules.

Key principles encoded:
- Never pause to ask "should I continue?" after each file
- Never create throwaway scripts without cleanup (/tmp or delete)
- Commit only when explicitly requested (but prepare conventional commit message)
- Final output must include what changed, what verified, what needs human input

## Manual Install

If you don’t want `install.sh`:

```bash
# 1. Backup
cp ~/.config/opencode/opencode.json ~/.config/opencode/opencode.json.bak.$(date +%s)

# 2. Merge autonomy settings (manually edit file)
# Copy keys from opencode.json.example: subagent_depth, tool_output, compaction, formatter, lsp, experimental, permission, agent.build.steps etc.
# Or replace fully (sanitize provider keys first)

# 3. Copy agents
mkdir -p ~/.config/opencode/agents
cp agents/*.md ~/.config/opencode/agents/

# 4. Copy commands
mkdir -p ~/.config/opencode/commands
cp commands/*.md ~/.config/opencode/commands/

# 5. Optionally set global AGENTS.md
cp AGENTS.md.example ~/.config/opencode/AGENTS.md # if you don't have one

# 6. Verify
opencode debug config | jq '.agent | keys'
opencode models
```

## Tips

- **Use `--auto`**: `opencode --auto` auto-approves any remaining `ask` permissions. With `allow` config it's mostly insurance, but useful when per-project configs are restrictive. Alias: `alias oc='opencode --auto'`
- **TodoWrite for 3+ steps**: Forces structured execution, helps resume after compaction
- **Subagents are cheap**: Use `@explore` for parallel searches, `@general` for research, chain them (depth 3)
- **Formatter + LSP are enabled**: Lean on them for autofix, check diagnostics rather than guessing
- **small_model**: fast model for title generation; put heavy lifting on main model
- **Compaction**: tail 12 keeps recent context verbatim; long sessions survive summarization
- **tool_output 5000/200KB**: You can grep full logs without re-running
- **Snapshot**: `snapshot: true` enables undo/redo of file changes in TUI (`/undo`, `/redo`)
- **Per-project overrides**: Drop `opencode.json` in repo root with project-specific `instructions`, `agent` tweaks — it deep-merges over global

## Uninstall / Rollback

```bash
# Restore backup
ls ~/.config/opencode/opencode.json.bak.*
cp ~/.config/opencode/opencode.json.bak.<timestamp> ~/.config/opencode/opencode.json

# Or remove autonomy
rm ~/.config/opencode/agents/autonomous.md ~/.config/opencode/agents/ultrawork.md ~/.config/opencode/agents/build.md ~/.config/opencode/agents/fixer.md ~/.config/opencode/agents/reviewer.md
rm ~/.config/opencode/commands/ship.md ~/.config/opencode/commands/autofix.md ~/.config/opencode/commands/ultrawork.md ~/.config/opencode/commands/fix.md ~/.config/opencode/commands/review.md
```

## Repo Structure

```
.
├── README.md
├── LICENSE
├── install.sh
├── scripts/
│   └── detect-oracle.sh
├── templates/
│   └── ship/
│       ├── SPEC.template.md
│       └── DOD.template.md
├── opencode.json.example          # Full annotated high-autonomy config (no secrets)
├── opencode.json.minimal.example  # Minimal patch: only autonomy keys
├── AGENTS.md.example              # Generic high-autonomy AGENTS.md
├── agents/
│   ├── autonomous.md
│   ├── ultrawork.md
│   ├── build.md
│   ├── specifier.md
│   ├── fixer.md
│   └── reviewer.md
├── commands/
│   ├── ship.md
│   ├── verify.md
│   ├── autofix.md
│   ├── ultrawork.md
│   ├── fix.md
│   └── review.md
├── .opencode.example/             # Per-project example
│   ├── opencode.json
│   └── AGENTS.md
└── docs/
    ├── CONFIG.md
    ├── AGENTS.md
    ├── COMMANDS.md
    └── TIPS.md
```

## License

MIT — see LICENSE.

---

Made for people who want less "should I continue?" and more shipped.
