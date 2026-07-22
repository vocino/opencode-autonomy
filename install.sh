#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# opencode-autonomy installer - bloat-free, idempotent, clean by default with --clean
# --clean ensures dest matches repo exactly: removes stale agents/commands/templates/scripts from old versions
# and prunes backup bloat.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err()  { printf "${RED}[ERR]${NC} %s\n" "$*" >&2; }

CLEAN=0
KEEP_BACKUPS=3

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --keep-backups=*) KEEP_BACKUPS="${arg#*=}";;
    --help|-h)
      echo "Usage: ./install.sh [--clean] [--keep-backups=N]"
      echo ""
      echo "  --clean              Remove stale files from old versions (agents, commands, templates, scripts not in current repo)"
      echo "                       Also prunes old .bak.* backups to last N (default 3). Recommended for one-shot prompt."
      echo "  --keep-backups=N     Number of opencode.json backups to keep (default 3)"
      echo "  --help               Show this help"
      exit 0
      ;;
    *) warn "Unknown arg: $arg (ignored)";;
  esac
done

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
[[ $CLEAN -eq 1 ]] && info "Mode: CLEAN (bloat-free, will remove stale files)" || info "Mode: MERGE (adds/updates, keeps existing custom files)"

# Track what we clean for reporting
CLEANED_COUNT=0

prune_backups() {
  local backup_pattern="$DEST_DIR/opencode.json.bak.*"
  local backups=()
  mapfile -t backups < <(ls -t $backup_pattern 2>/dev/null || true)
  if (( ${#backups[@]} > KEEP_BACKUPS )); then
    local to_delete=("${backups[@]:KEEP_BACKUPS}")
    for f in "${to_delete[@]}"; do
      rm -f "$f"
      CLEANED_COUNT=$((CLEANED_COUNT + 1))
      warn "Pruned old backup: $(basename "$f")"
    done
    ok "Pruned backups to last $KEEP_BACKUPS"
  fi
}

# 1. Backup existing opencode.json if exists
if [[ -f "$DEST_DIR/opencode.json" ]]; then
  cp "$DEST_DIR/opencode.json" "$DEST_DIR/opencode.json.$BACKUP_SUFFIX"
  ok "Backed up opencode.json → opencode.json.$BACKUP_SUFFIX"
  [[ $CLEAN -eq 1 ]] && prune_backups
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
    jq -s '
      .[0] as $existing |
      .[1] as $example |
      ($existing.agent.build.prompt // null) as $user_prompt |
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
      [[ $CLEAN -eq 1 ]] && prune_backups
    else
      err "Merged JSON invalid - keeping original, backup is $BACKUP_SUFFIX"
      exit 1
    fi
  else
    warn "jq not found - skipping auto-merge. Manually copy keys from opencode.json.example"
  fi
fi

# Helper: sync files and optionally clean stale
sync_files() {
  local src_glob="$1"
  local dest_dir="$2"
  local label="$3"
  local src_files=()
  local src_basenames=()
  local count=0
  local dest_file
  local base
  local found

  shopt -s nullglob
  for f in $src_glob; do
    src_files+=("$f")
    src_basenames+=("$(basename "$f")")
  done

  for f in "${src_files[@]}"; do
    base="$(basename "$f")"
    cp "$f" "$dest_dir/$base"
    # preserve executable if source is executable
    [[ -x "$f" ]] && chmod +x "$dest_dir/$base" || true
    count=$((count + 1))
  done

  if [[ $count -gt 0 ]]; then
    ok "Installed $count $label file(s)"
  else
    warn "No $label files found for pattern $src_glob"
  fi

  if [[ $CLEAN -eq 1 ]]; then
    for dest_file in "$dest_dir"/*; do
      [[ -f "$dest_file" ]] || continue
      base="$(basename "$dest_file")"
      found=0
      for src_base in "${src_basenames[@]}"; do
        if [[ "$base" == "$src_base" ]]; then
          found=1
          break
        fi
      done
      if [[ $found -eq 0 ]]; then
        # Only clean files that look like our autonomy files (md or sh), not arbitrary user dotfiles
        case "$base" in
          *.md|*.sh|*.mdc)
            rm -f "$dest_file"
            CLEANED_COUNT=$((CLEANED_COUNT + 1))
            warn "Cleaned stale $label: $base (not in current repo)"
            ;;
        esac
      fi
    done
  fi
}

# 3. Agents - exact sync when --clean
sync_files "$SRC_DIR/agents/*.md" "$DEST_AGENTS" "agent"

# 4. Commands - exact sync when --clean
sync_files "$SRC_DIR/commands/*.md" "$DEST_COMMANDS" "command"

# 5. Templates - full dir sync
if [[ -d "$SRC_DIR/templates" ]]; then
  if [[ $CLEAN -eq 1 ]]; then
    # remove dest templates entirely then copy fresh to guarantee no leftover bloat
    rm -rf "$DEST_TEMPLATES"
    mkdir -p "$DEST_TEMPLATES"
    cp -R "$SRC_DIR/templates/." "$DEST_TEMPLATES/"
    ok "Installed templates into $DEST_TEMPLATES (clean sync, removed old)"
  else
    cp -R "$SRC_DIR/templates/." "$DEST_TEMPLATES/"
    ok "Installed templates into $DEST_TEMPLATES"
  fi
else
  warn "No templates directory found in $SRC_DIR/templates/"
fi

# 6. Scripts - exact sync when --clean
sync_files "$SRC_DIR/scripts/*.sh" "$DEST_SCRIPTS" "script"
chmod +x "$DEST_SCRIPTS"/*.sh 2>/dev/null || true

# 7. AGENTS.md - only if not exists (never overwrite user)
if [[ ! -f "$DEST_DIR/AGENTS.md" ]]; then
  cp "$SRC_DIR/AGENTS.md.example" "$DEST_DIR/AGENTS.md"
  ok "Installed AGENTS.md"
else
  warn "AGENTS.md exists - not overwriting. Diff:"
  info "  diff -u $DEST_DIR/AGENTS.md $SRC_DIR/AGENTS.md.example | head -80"
fi

# 7.5 Githooks template
if [[ -d "$SRC_DIR/.githooks" ]]; then
  mkdir -p "$DEST_TEMPLATES/githooks"
  cp "$SRC_DIR/.githooks/"* "$DEST_TEMPLATES/githooks/" 2>/dev/null || true
  ok "Installed githooks template → $DEST_TEMPLATES/githooks/"
fi

# Install local git hook in source repo (dev convenience)
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
if [[ $CLEAN -eq 1 ]]; then
  ok "Done (CLEAN)! Removed $CLEANED_COUNT stale files/backups, synced exactly to repo."
else
  ok "Done! (merge mode)"
  info "Run with --clean to remove stale files from old versions: ./install.sh --clean"
fi
echo
info "Restart opencode (quit + opencode) to load new config"
echo
info "Set OPENROUTER_API_KEY before first run if not already set"
info "Try: /ship Implement a hello world component"
info "Try: /verify .opencode/state/ship/<run-id>"
info "Agents: $(ls "$SRC_DIR/agents"/*.md 2>/dev/null | xargs -I{} basename {} .md | tr '\n' ',' | sed 's/,$//')"
info "Docs: https://github.com/vocino/opencode-autonomy"
