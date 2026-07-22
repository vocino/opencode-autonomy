#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# opencode-autonomy installer
# Backs up existing config, merges high-autonomy settings, copies agents & commands

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err()  { printf "${RED}[ERR]${NC} %s\n" "$*" >&2; }

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
DEST_AGENTS="$DEST_DIR/agents"
DEST_COMMANDS="$DEST_DIR/commands"
DEST_TEMPLATES="$DEST_DIR/templates"
DEST_SCRIPTS="$DEST_DIR/scripts"
BACKUP_SUFFIX="bak.$(date +%s)"

TMP=""
cleanup() {
  if [[ -n "$TMP" && -f "$TMP" ]]; then
    rm -f "$TMP"
  fi
}
trap cleanup EXIT

mkdir -p "$DEST_DIR" "$DEST_AGENTS" "$DEST_COMMANDS" "$DEST_TEMPLATES" "$DEST_SCRIPTS"

info "Source: $SRC_DIR"
info "Dest: $DEST_DIR"

# 1. Backup existing opencode.json if exists
if [[ -f "$DEST_DIR/opencode.json" ]]; then
  cp "$DEST_DIR/opencode.json" "$DEST_DIR/opencode.json.$BACKUP_SUFFIX"
  ok "Backed up opencode.json → opencode.json.$BACKUP_SUFFIX"
fi

# 2. Create or merge config
if [[ ! -f "$DEST_DIR/opencode.json" ]]; then
  cp "$SRC_DIR/opencode.json.minimal.example" "$DEST_DIR/opencode.json"
  ok "Created $DEST_DIR/opencode.json from minimal.example"
  if command -v jq >/dev/null 2>&1; then
    TMP="$(mktemp)"
    jq -s '
      .[0] as $created |
      .[1] as $example |
      $created
      | .default_agent = (.default_agent // $example.default_agent // "build")
      | .model = (.model // $example.model // "openrouter/anthropic/claude-sonnet-4-5")
      | .small_model = (.small_model // $example.small_model)
      | .provider = ((.provider // {}) * ($example.provider // {}))
      | .instructions = ((.instructions // []) + ($example.instructions // []) | unique)
      | .agent = ((.agent // {}) * ($example.agent // {}))
    ' "$DEST_DIR/opencode.json" "$SRC_DIR/opencode.json.example" > "$TMP"
    mv "$TMP" "$DEST_DIR/opencode.json"
    TMP=""
    ok "Seeded default_agent/instructions/agent metadata from opencode.json.example"
  fi
  echo
  info "Add your model, e.g.:"
  echo "  { \"\$schema\": \"https://opencode.ai/config.json\", \"model\": \"openrouter/anthropic/claude-sonnet-4-5\" }"
  echo
else
  info "Merging autonomy settings into existing config..."
  if command -v jq >/dev/null 2>&1; then
    TMP="$(mktemp)"
    # Merge autonomy keys from example into existing config.
    # Preserves user's model/provider and custom prompts.
    jq -s '
      .[0] as $existing |
      .[1] as $example |
      ($existing.agent.build.prompt // null) as $user_prompt |
      # autonomy keys to always overwrite from example
      ["$schema","snapshot","subagent_depth","formatter","lsp","tool_output","compaction","watcher","experimental","permission"] as $keys |
      ($keys | map({key: ., value: $example[.]}) | from_entries) as $autonomy |
      (
        ($existing.instructions // []) + ($example.instructions // [])
        | map(select(type == "string"))
        | unique
      ) as $merged_instructions |
      ($existing * $autonomy)
      | .instructions = $merged_instructions
      | .default_agent = (.default_agent // $example.default_agent // "build")
      | .small_model = (.small_model // $example.small_model)
      | .provider = ((.provider // {}) * ($example.provider // {}))
      | .agent = (($existing.agent // {}) * ($example.agent // {}))
      | if $user_prompt != null then .agent.build.prompt = $user_prompt else . end
    ' "$DEST_DIR/opencode.json" "$SRC_DIR/opencode.json.example" > "$TMP"

    if jq empty "$TMP" 2>/dev/null; then
      mv "$TMP" "$DEST_DIR/opencode.json"
      TMP=""
      ok "Merged autonomy settings (backup kept)"
    else
      err "Merged JSON invalid - keeping original, backup is $BACKUP_SUFFIX"
      exit 1
    fi
  else
    warn "jq not found - skipping auto-merge. Manually copy keys from opencode.json.example"
    warn "See docs/CONFIG.md for which keys to copy"
  fi
fi

# 3. Copy agents
agent_count=0
for f in "$SRC_DIR"/agents/*.md; do
  base="$(basename "$f")"
  cp "$f" "$DEST_AGENTS/$base"
  ok "Installed agent $base"
  agent_count=$((agent_count + 1))
done
(( agent_count == 0 )) && warn "No agent files found in $SRC_DIR/agents/"

# 4. Copy commands
cmd_count=0
for f in "$SRC_DIR"/commands/*.md; do
  base="$(basename "$f")"
  cp "$f" "$DEST_COMMANDS/$base"
  ok "Installed command $base"
  cmd_count=$((cmd_count + 1))
done
(( cmd_count == 0 )) && warn "No command files found in $SRC_DIR/commands/"

# 5. Copy templates
if [[ -d "$SRC_DIR/templates" ]]; then
  cp -R "$SRC_DIR/templates/." "$DEST_TEMPLATES/"
  ok "Installed templates into $DEST_TEMPLATES"
else
  warn "No templates directory found in $SRC_DIR/templates/"
fi

# 6. Copy helper scripts
script_count=0
for f in "$SRC_DIR"/scripts/*.sh; do
  base="$(basename "$f")"
  cp "$f" "$DEST_SCRIPTS/$base"
  chmod +x "$DEST_SCRIPTS/$base"
  ok "Installed script $base"
  script_count=$((script_count + 1))
done
(( script_count == 0 )) && warn "No shell scripts found in $SRC_DIR/scripts/"

# 7. AGENTS.md - only if not exists
if [[ ! -f "$DEST_DIR/AGENTS.md" ]]; then
  cp "$SRC_DIR/AGENTS.md.example" "$DEST_DIR/AGENTS.md"
  ok "Installed AGENTS.md"
else
  warn "AGENTS.md exists - not overwriting. Diff:"
  info "  diff -u $DEST_DIR/AGENTS.md $SRC_DIR/AGENTS.md.example | head -80"
fi

# 7.5 Cursor no-attribution rule + git hooks (prevent AI branding in commits)
if [[ -f "$SRC_DIR/.cursor/rules/no-attribution.mdc" ]]; then
  # Copy as template for users to reference
  mkdir -p "$DEST_TEMPLATES/cursor"
  cp "$SRC_DIR/.cursor/rules/no-attribution.mdc" "$DEST_TEMPLATES/cursor/no-attribution.mdc"
  ok "Installed cursor no-attribution rule template → $DEST_TEMPLATES/cursor/no-attribution.mdc"
  info "  To use in a project: mkdir -p .cursor/rules && cp ~/.config/opencode/templates/cursor/no-attribution.mdc .cursor/rules/"
fi

if [[ -d "$SRC_DIR/.githooks" ]]; then
  mkdir -p "$DEST_TEMPLATES/githooks"
  cp "$SRC_DIR/.githooks/"* "$DEST_TEMPLATES/githooks/" 2>/dev/null || true
  ok "Installed githooks template → $DEST_TEMPLATES/githooks/"
fi

# If we're inside a git repo (the source repo itself), install the hook locally
if [[ -d "$SRC_DIR/.git" && -f "$SRC_DIR/scripts/install-git-hooks.sh" ]]; then
  if "$SRC_DIR/scripts/install-git-hooks.sh" 2>&1 | sed 's/^/  /'; then
    ok "Installed local git commit-msg hook (strips cursoragent)"
  else
    warn "Failed to install local git hook"
  fi
fi

# 8. Validate binary and config
if command -v opencode >/dev/null 2>&1; then
  ok "opencode binary: $(opencode --version 2>&1 | head -1)"
  info "Validating config..."
  if opencode debug config >/dev/null 2>&1; then
    ok "Config valid"
    opencode debug config 2>&1 | jq -r '.agent | keys | join(", ")' 2>/dev/null || true
  else
    err "Config validation failed - check: opencode debug config"
    err "Restore: cp $DEST_DIR/opencode.json.$BACKUP_SUFFIX $DEST_DIR/opencode.json"
    exit 1
  fi
else
  warn "opencode binary not found - install from https://opencode.ai"
fi

echo
ok "Done! Restart opencode (quit + opencode) to load new config"
echo
info "Set OPENROUTER_API_KEY before first run if not already set"
info "Try: /ship Implement a hello world component"
info "Try: /verify .opencode/state/ship/<run-id>"
info "Agents: autonomous (300), ultrawork (400), build (200), specifier, fixer, reviewer"
info "Docs: https://github.com/vocino/opencode-autonomy"
