#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

info() {
  printf '[INFO] %s\n' "$*"
}

pass() {
  printf '[PASS] %s\n' "$*"
}

require_cmd() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "Expected file missing: $path"
}

assert_executable() {
  local path="$1"
  [[ -x "$path" ]] || fail "Expected executable missing execute bit: $path"
}

check_frontmatter() {
  local file="$1"
  local key="$2"
  local first_line=""
  local end_line=""

  first_line="$(awk 'NR == 1 { print; exit }' "$file")"
  [[ "$first_line" == "---" ]] || fail "Frontmatter start missing in $file"

  end_line="$(awk 'NR > 1 && $0 == "---" { print NR; exit }' "$file")"
  [[ -n "$end_line" ]] || fail "Frontmatter end missing in $file"

  if ! awk -v target_key="$key" -v stop_line="$end_line" '
      NR < stop_line && $0 ~ ("^" target_key ":") { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "$file"; then
    fail "Frontmatter key \"$key\" missing in $file"
  fi
}

contains_line() {
  local haystack="$1"
  local needle="$2"
  local line=""

  while IFS= read -r line; do
    if [[ "$line" == "$needle" ]]; then
      return 0
    fi
  done <<< "$haystack"

  return 1
}

info "Checking markdown frontmatter conventions..."
for file in commands/*.md; do
  check_frontmatter "$file" "description"
  check_frontmatter "$file" "agent"
done
for file in agents/*.md; do
  check_frontmatter "$file" "description"
  check_frontmatter "$file" "mode"
done
pass "Frontmatter validated for commands and agents"

require_cmd jq

info "Validating JSON config examples..."
jq empty opencode.json.example
jq empty opencode.json.minimal.example
jq -e '.model | startswith("openrouter/")' opencode.json.example >/dev/null
jq -e '.small_model | startswith("openrouter/")' opencode.json.example >/dev/null
jq -e '.provider.openrouter.options.apiKey == "{env:OPENROUTER_API_KEY}"' opencode.json.example >/dev/null
jq -e '.small_model | startswith("openrouter/")' opencode.json.minimal.example >/dev/null
jq -e '.provider.openrouter.options.apiKey == "{env:OPENROUTER_API_KEY}"' opencode.json.minimal.example >/dev/null
pass "JSON config examples are valid"

info "Smoke-checking oracle detection output..."
oracle_output="$(bash scripts/detect-oracle.sh)"
[[ -n "$oracle_output" ]] || fail "scripts/detect-oracle.sh produced empty output"
contains_line "$oracle_output" "shellcheck install.sh" || fail "detect-oracle missing shellcheck install command"
contains_line "$oracle_output" "bash tests/validate.sh" || fail "detect-oracle missing validation harness command"
pass "Oracle detection outputs expected baseline commands"

info "Running install smoke test in temporary XDG_CONFIG_HOME..."
tmp_root="$(mktemp -d)"
install_log="$tmp_root/install.log"
trap 'rm -rf "$tmp_root"' EXIT

XDG_CONFIG_HOME="$tmp_root" ./install.sh >"$install_log" 2>&1

dest="$tmp_root/opencode"
assert_file "$dest/opencode.json"
assert_file "$dest/AGENTS.md"
assert_file "$dest/agents/autonomous.md"
assert_file "$dest/agents/specifier.md"
assert_file "$dest/commands/ship.md"
assert_file "$dest/commands/verify.md"
assert_file "$dest/templates/ship/SPEC.template.md"
assert_file "$dest/templates/ship/DOD.template.md"
assert_file "$dest/scripts/detect-oracle.sh"
assert_executable "$dest/scripts/detect-oracle.sh"
jq empty "$dest/opencode.json" >/dev/null
pass "Install smoke test (fresh config) passed"

info "Running install merge smoke test..."
cat > "$dest/opencode.json" <<'JSON'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "custom/test-model",
  "instructions": ["custom.md"],
  "agent": {
    "build": {
      "prompt": "KEEP_THIS_PROMPT"
    }
  }
}
JSON

XDG_CONFIG_HOME="$tmp_root" ./install.sh >>"$install_log" 2>&1

jq -e '.model == "custom/test-model"' "$dest/opencode.json" >/dev/null || fail "Model should be preserved on merge"
jq -e '.small_model | startswith("openrouter/")' "$dest/opencode.json" >/dev/null || fail "small_model should default from OpenRouter example when missing"
jq -e '.provider.openrouter.options.apiKey == "{env:OPENROUTER_API_KEY}"' "$dest/opencode.json" >/dev/null || fail "OpenRouter provider should default from example when missing"
jq -e '.agent.build.prompt == "KEEP_THIS_PROMPT"' "$dest/opencode.json" >/dev/null || fail "User build prompt should be preserved on merge"
jq -e '.instructions | index("custom.md") != null' "$dest/opencode.json" >/dev/null || fail "Custom instruction should be preserved on merge"
jq -e '.instructions | index("AGENTS.md") != null' "$dest/opencode.json" >/dev/null || fail "AGENTS.md instruction should exist after merge"
jq -e '.agent.specifier != null' "$dest/opencode.json" >/dev/null || fail "Specifier agent metadata missing after merge"
backup_files=("$dest"/opencode.json.bak.*)
(( ${#backup_files[@]} > 0 )) || fail "Expected config backup files after merge install"
pass "Install merge smoke test passed"

if command -v opencode >/dev/null 2>&1; then
  info "Validating generated config with opencode debug config..."
  if XDG_CONFIG_HOME="$tmp_root" opencode debug config >/dev/null 2>&1; then
    pass "opencode debug config passed for smoke install"
  else
    fail "opencode debug config failed for smoke install"
  fi
else
  info "Skipping opencode debug config (opencode not installed)"
fi

pass "All validation checks passed"
