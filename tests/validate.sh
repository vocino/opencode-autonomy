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
# no duplicate among agents (except build == top-level model is allowed)
dups_agents=$(jq -r '.agent[]?.model // empty' opencode.json.example | sort | uniq -d)
[[ -z "$dups_agents" ]] || fail "duplicate model IDs among agents found: $dups_agents"
# ensure total distinct is 5
# total entries = model, small_model + 4 agents = 6, distinct should be 5 (build duplicates model)
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

# smoke install
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
XDG_CONFIG_HOME="$tmp" ./install.sh >/tmp/install.log 2>&1
[[ -f "$tmp/opencode/opencode.json" ]] || fail "smoke install: opencode.json missing"
[[ -f "$tmp/opencode/agents/build.md" ]] || fail "smoke install: build.md missing"
[[ -f "$tmp/opencode/agents/fixer.md" ]] || fail "smoke install: fixer.md missing"
[[ -f "$tmp/opencode/commands/ship.md" ]] || fail "smoke install: ship.md missing"
[[ -f "$tmp/opencode/commands/fix.md" ]] || fail "smoke install: fix.md missing"
jq empty "$tmp/opencode/opencode.json" || fail "smoke installed json invalid"
jq -e '.model=="meta/muse-spark-1.1"' "$tmp/opencode/opencode.json" >/dev/null || fail "smoke install model should be meta"
pass "smoke install fresh ok"

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

pass "all checks passed"
