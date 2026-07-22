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
jq -e '.model|startswith("openrouter/")' opencode.json.example >/dev/null || fail "model should be openrouter/"
jq -e '.agent.build' opencode.json.example >/dev/null || fail "build agent missing"
jq -e '.agent.fixer' opencode.json.example >/dev/null || fail "fixer agent missing"
pass "config valid"

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
[[ $(ls "$tmp/opencode"/opencode.json.bak.* 2>/dev/null | wc -l) -le 3 ]] || fail "--clean should prune backups to 3"
[[ $(ls "$tmp/opencode/agents"/*.md 2>/dev/null | wc -l) -eq $(ls "$ROOT"/agents/*.md 2>/dev/null | wc -l) ]] || fail "--clean agent count mismatch"
pass "clean bloat test ok (stale removal + backup prune)"

if command -v opencode >/dev/null; then
  XDG_CONFIG_HOME="$tmp" opencode debug config >/dev/null 2>&1 && pass "opencode debug config ok" || fail "opencode debug config failed"
else
  echo "[INFO] opencode not installed, skipping debug config"
fi

pass "all checks passed"
