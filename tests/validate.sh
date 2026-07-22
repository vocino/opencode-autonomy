#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

# frontmatter
for f in agents/*.md; do grep -q "^description:" "$f" || fail "description missing in $f"; grep -q "^mode:" "$f" || fail "mode missing in $f"; done
for f in commands/*.md; do grep -q "^description:" "$f" || fail "description missing in $f"; grep -q "^agent:" "$f" || fail "agent missing in $f"; done
pass "frontmatter ok"

command -v jq >/dev/null || fail "jq required"
jq empty opencode.json.example || fail "invalid opencode.json.example"
jq empty package.json || fail "invalid package.json"
pass "json valid"

# AC-1: strong default meta
jq -e '.model=="meta/muse-spark-1.1"' opencode.json.example >/dev/null || fail "model should be meta/muse-spark-1.1"
jq -e '.small_model=="openrouter/google/gemini-flash-latest"' opencode.json.example >/dev/null || fail "small_model should be google flash"

# AC-2: providers include meta + openrouter, no secrets
jq -e '.provider.meta' opencode.json.example >/dev/null || fail "meta provider missing"
jq -e '.provider.openrouter' opencode.json.example >/dev/null || fail "openrouter provider missing"
jq -e '.provider.meta.options.apiKey|startswith("{file:")' opencode.json.example >/dev/null || fail "meta apiKey should be {file:}"
jq -e '.provider.openrouter.options.apiKey=="{env:OPENROUTER_API_KEY}"' opencode.json.example >/dev/null || fail "openrouter apiKey should be env"

# AC-3: 5 distinct models, varied families, no dup
distinct=$(jq -r '[.model, .small_model] + [.agent[]?.model // empty] | unique | .[]' opencode.json.example | sort -u)
count=$(echo "$distinct" | wc -l)
[[ "$count" -eq 5 ]] || fail "should have 5 distinct models, got $count: $distinct"
echo "$distinct" | grep -q "meta/muse-spark-1.1" || fail "missing meta family"
echo "$distinct" | grep -q "google/gemini" || fail "missing google family"
echo "$distinct" | grep -q "anthropic/" || fail "missing anthropic family"
echo "$distinct" | grep -q "openai/" || fail "missing openai family"
echo "$distinct" | grep -q "qwen/" || fail "missing qwen family"
dups_agents=$(jq -r '.agent[]?.model // empty' opencode.json.example | sort | uniq -d)
[[ -z "$dups_agents" ]] || fail "duplicate model IDs among agents found: $dups_agents"
total_entries=$(jq -r '[.model, .small_model] + [.agent[]?.model // empty] | length' opencode.json.example)
[[ "$total_entries" -eq 6 ]] || fail "expected 6 model entries (model+small+4 agents), got $total_entries"

# AC-4: agents use varied models
jq -e '.agent.build.model=="meta/muse-spark-1.1"' opencode.json.example >/dev/null || fail "build should use meta"
jq -e '.agent.fixer.model=="openrouter/anthropic/claude-sonnet-4-5"' opencode.json.example >/dev/null || fail "fixer should use anthropic"
jq -e '.agent.explore.model=="openrouter/qwen/qwen3-coder"' opencode.json.example >/dev/null || fail "explore should use qwen"
jq -e '.agent.plan.model=="openrouter/openai/gpt-4o-mini"' opencode.json.example >/dev/null || fail "plan should use openai"

jq -e '.agent.build' opencode.json.example >/dev/null || fail "build agent missing"
jq -e '.agent.fixer' opencode.json.example >/dev/null || fail "fixer agent missing"
pass "config valid — 5 models: $(echo $distinct | tr '\n' ',' | sed 's/,$//')"

out="$(bash scripts/detect-oracle.sh)"; [[ -n "$out" ]] || fail "oracle empty"
echo "$out" | grep -q "bash tests/validate.sh" || fail "oracle missing validate"
pass "oracle ok: $(echo "$out" | tr '\n' ',' | cut -c1-120)"

# npm package checks
jq -e '.name=="opencode-autonomy"' package.json >/dev/null || fail "package name should be opencode-autonomy"
jq -e '.bin."opencode-autonomy"' package.json >/dev/null || fail "package bin missing"
jq -e '.exports."."' package.json >/dev/null || fail "exports . missing"
jq -e '.exports."./plugin"' package.json >/dev/null || fail "exports ./plugin missing"
jq -e '.files|contains(["dist/"])' package.json >/dev/null || fail "files should contain dist/"
jq -e '.type=="module"' package.json >/dev/null || fail "package type should be module"
[[ -f bin/cli.mjs ]] || fail "bin/cli.mjs missing"
[[ -x bin/cli.mjs ]] || fail "bin/cli.mjs not executable"
[[ -f tsconfig.json ]] || fail "tsconfig.json missing"
[[ -f src/plugin.ts ]] || fail "src/plugin.ts missing"
[[ -f src/index.ts ]] || fail "src/index.ts missing"
[[ -f src/autonomy.ts ]] || fail "src/autonomy.ts missing"
pass "npm package structure ok"

# TypeScript build check
if command -v npx >/dev/null; then
  if [[ -d node_modules ]]; then
    npx tsc -p tsconfig.json --noEmit || fail "tsc typecheck failed"
    pass "tsc typecheck ok"
    npx tsc -p tsconfig.json || fail "tsc build failed"
    [[ -f dist/plugin.js ]] || fail "dist/plugin.js not built"
    [[ -f dist/index.js ]] || fail "dist/index.js not built"
    [[ -f dist/autonomy.js ]] || fail "dist/autonomy.js not built"
    pass "tsc build ok (dist exists)"
  else
    echo "[INFO] node_modules missing, skipping tsc build"
  fi
fi

# Plugin load check
if command -v node >/dev/null && [[ -f dist/plugin.js ]]; then
  node --input-type=module <<'NODE' || fail "plugin.js failed to load"
import plugin from './dist/plugin.js';
if (typeof plugin !== 'function') throw new Error('plugin default not function');
const hooks = await plugin();
if (!hooks.config) throw new Error('config hook missing');
console.log('plugin load ok');
NODE
  pass "plugin.js loads and exposes config hook"
fi

# CLI checks
if command -v node >/dev/null; then
  node ./bin/cli.mjs --help 2>&1 | grep -q "opencode-autonomy" || fail "cli --help broken"
  node ./bin/cli.mjs --version 2>&1 | grep -qE "[0-9]+\.[0-9]+" || fail "cli --version broken"
  node ./bin/cli.mjs --dry-run --dest /tmp/validate-dry 2>&1 | grep -q "AUTONOMY MODE" || fail "cli should print autonomy notice"
  pass "cli --help/--version/dry-run ok"
fi

# smoke install via shell script
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
XDG_CONFIG_HOME="$tmp" ./install.sh >/tmp/install.log 2>&1
[[ -f "$tmp/opencode/opencode.json" ]] || fail "smoke install: opencode.json missing"
[[ -f "$tmp/opencode/agents/build.md" ]] || fail "smoke install: build.md missing"
[[ -f "$tmp/opencode/agents/fixer.md" ]] || fail "smoke install: fixer.md missing"
[[ -f "$tmp/opencode/commands/ship.md" ]] || fail "smoke install: ship.md missing"
[[ -f "$tmp/opencode/commands/fix.md" ]] || fail "smoke install: fix.md missing"
jq empty "$tmp/opencode/opencode.json" || fail "smoke installed json invalid"
jq -e '.model=="meta/muse-spark-1.1"' "$tmp/opencode/opencode.json" >/dev/null || fail "smoke install model should be meta"
jq -e '.permission."*"=="allow"' "$tmp/opencode/opencode.json" >/dev/null || fail "smoke install should have allow-all permission"
pass "smoke install fresh ok"

# smoke install via node cli
tmp2=$(mktemp -d)
node ./bin/cli.mjs --dest "$tmp2/opencode" >/tmp/cli-install.log 2>&1
[[ -f "$tmp2/opencode/opencode.json" ]] || fail "cli smoke install: opencode.json missing"
[[ -f "$tmp2/opencode/agents/build.md" ]] || fail "cli smoke install: build.md missing"
jq -e '.permission."*"=="allow"' "$tmp2/opencode/opencode.json" >/dev/null || fail "cli smoke install should have allow-all permission"
rm -rf "$tmp2"
pass "cli smoke install ok"

# merge preserve
echo '{"model":"custom/model","provider":{"custom":{"options":{}}}}' > "$tmp/opencode/opencode.json"
XDG_CONFIG_HOME="$tmp" ./install.sh >>/tmp/install.log 2>&1
jq -e '.model=="custom/model"' "$tmp/opencode/opencode.json" >/dev/null || fail "merge should preserve model"
pass "smoke merge preserves model"

# clean bloat test
echo "stale" > "$tmp/opencode/agents/stale-old.md"
touch "$tmp/opencode/opencode.json.bak.1" "$tmp/opencode/opencode.json.bak.2" "$tmp/opencode/opencode.json.bak.3" "$tmp/opencode/opencode.json.bak.4"
XDG_CONFIG_HOME="$tmp" ./install.sh --clean >>/tmp/install.log 2>&1
[[ ! -f "$tmp/opencode/agents/stale-old.md" ]] || fail "--clean should delete stale agent"
[[ $(ls "$tmp"/opencode.json.bak.* 2>/dev/null | wc -l) -le 3 ]] || fail "--clean should prune backups to 3"
[[ $(ls "$tmp/opencode/agents"/*.md 2>/dev/null | wc -l) -eq $(ls "$ROOT"/agents/*.md 2>/dev/null | wc -l) ]] || fail "--clean agent count mismatch"
pass "clean bloat test ok (stale removal + backup prune)"

if command -v opencode >/dev/null; then
  if XDG_CONFIG_HOME="$tmp" opencode debug config >/dev/null 2>&1; then
    pass "opencode debug config ok"
  else
    fail "opencode debug config failed — $(XDG_CONFIG_HOME="$tmp" opencode debug config 2>&1 | head -n 20)"
  fi
else
  echo "[INFO] opencode not installed, skipping debug config"
fi

# npm pack check
if command -v npm >/dev/null; then
  pack_out=$(npm pack --dry-run 2>&1 || true)
  echo "$pack_out" | grep -q "dist/" || fail "npm pack should include dist/"
  echo "$pack_out" | grep -q "agents/" || fail "npm pack should include agents/"
  echo "$pack_out" | grep -q "bin/" || fail "npm pack should include bin/"
  pass "npm pack contains required files"
fi

# README autonomy warning check
grep -q "Autonomy & Permissions" README.md || fail "README should have autonomy section"
grep -q "ALLOW.*allow" README.md || grep -q '"\*":"allow"' README.md || fail "README should mention allow-all permission"
grep -q "npx opencode-autonomy" README.md || fail "README should mention npx"
grep -q "plugin.*opencode-autonomy" README.md || fail "README should mention plugin array"
pass "README contains autonomy warning + npx DX"

pass "all checks passed"
