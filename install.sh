#!/usr/bin/env bash
set -euo pipefail

# opencode-autonomy installer — trivial, verifiable, bloat-free, now npx-aware
# Supports:
#   ./install.sh
#   ./install.sh --clean
#   ./install.sh --dry-run
#   ./install.sh --disable
#   XDG_CONFIG_HOME override, --dest <path>
#
# Preferred new way: npx opencode-autonomy@latest --clean
# Legacy: git clone + ./install.sh still works

CLEAN=0; DRY=0; DISABLE=0; KEEP=3
DEST_OVERRIDE=""
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    --dry-run|-n) DRY=1 ;;
    --disable) DISABLE=1 ;;
    --dest=*) DEST_OVERRIDE="${arg#--dest=}" ;;
    --help|-h)
      cat <<'HELP'
opencode-autonomy installer (legacy shell path)

Usage:
  ./install.sh [--clean] [--dry-run] [--disable] [--dest <path>]
  npx opencode-autonomy --clean   (preferred)

What it does:
  - Merges autonomy keys into ~/.config/opencode/opencode.json
  - Copies agents/build.md, fixer.md, commands/ship.md, fix.md
  - Copies scripts/detect-oracle.sh
  - With --clean, deletes stale files + prunes backups to 3

Autonomy note:
  This sets permission {"*":"allow", external_directory:"allow", doom_loop:"allow"}
  Agents will NOT ask for permission — they ship end-to-end.
  Use plan agent (Tab) for ask-mode, or --disable to restore backup.

New: you can also add to opencode.json:
  "plugin": ["opencode-autonomy"]
for runtime enforcement without copying files.

HELP
      exit 0
      ;;
    *) ARGS+=("$arg") ;;
  esac
done

# Handle --dest <path> (two-word form)
for i in "${!ARGS[@]}"; do
  if [[ "${ARGS[$i]}" == "--dest" ]]; then
    DEST_OVERRIDE="${ARGS[$((i+1))]:-}"
    break
  fi
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "$DEST_OVERRIDE" ]]; then
  DEST="$DEST_OVERRIDE"
else
  DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
fi

mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/scripts"

echo "[INFO] $SRC -> $DEST (clean=$CLEAN dry=$DRY disable=$DISABLE)"

cat <<'NOTICE'

⚠️  AUTONOMY MODE — Opinionated permissions:

  permission: {"*":"allow", external_directory:"allow", doom_loop:"allow"}
  → Agents will edit files, run bash, install deps WITHOUT asking.
  → They batch 3-5 files, verify lint/type/test/build, auto-fix.
  → Intended for long-horizon tasks with minimal intervention.

  Use Tab → 'plan' for ask-mode, or --disable to restore backup.
  See README#autonomy--permissions

NOTICE

if [[ $DISABLE -eq 1 ]]; then
  echo "[INFO] --disable: restoring latest backup if present"
  # shellcheck disable=SC2012
  latest=$(ls -t "$DEST"/opencode.json.bak.* 2>/dev/null | head -n1 || true)
  if [[ -n "$latest" && -f "$latest" ]]; then
    if [[ $DRY -eq 0 ]]; then cp "$latest" "$DEST/opencode.json"; fi
    echo "[OK] restored $latest -> opencode.json"
  else
    echo "[WARN] No backup found"
  fi
  exit 0
fi

if [[ -f "$DEST/opencode.json" ]]; then
  if [[ $DRY -eq 0 ]]; then
    cp "$DEST/opencode.json" "$DEST/opencode.json.bak.$(date +%s)"
    if [[ $CLEAN -eq 1 ]]; then
      # shellcheck disable=SC2012
      ls -t "$DEST"/opencode.json.bak.* 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -f || true
    fi
  else
    echo "[DRY] would backup $DEST/opencode.json"
  fi
fi

if [[ ! -f "$DEST/opencode.json" ]]; then
  if [[ $DRY -eq 1 ]]; then
    echo "[DRY] would create opencode.json from example"
  else
    cp "$SRC/opencode.json.example" "$DEST/opencode.json"
    echo "[OK] created opencode.json from example"
  fi
else
  if command -v jq >/dev/null 2>&1; then
    if [[ $DRY -eq 1 ]]; then
      echo "[DRY] would merge autonomy keys (preserve model/provider) into $DEST/opencode.json"
    else
      tmp=$(mktemp)
      jq -s '
        .[0] as $old | .[1] as $ex |
        ($old|{model,small_model,provider}) as $user |
        ($ex|{subagent_depth,snapshot,formatter,lsp,tool_output,compaction,experimental,permission,agent}) as $auto |
        ($old * $auto) * $user | .model //= $ex.model | .small_model //= $ex.small_model
      ' "$DEST/opencode.json" "$SRC/opencode.json.example" > "$tmp" && mv "$tmp" "$DEST/opencode.json"
      echo "[OK] merged autonomy keys (preserved model/provider)"
    fi
  else
    echo "[WARN] jq missing — skipping merge (install jq for proper merge)"
  fi
fi

sync_dir() {
  local pattern="$1" dest="$2"
  local cnt=0
  shopt -s nullglob
  # shellcheck disable=SC2206
  local files=($pattern)
  for f in "${files[@]}"; do
    if [[ $DRY -eq 0 ]]; then cp "$f" "$dest/"; fi
    cnt=$((cnt+1))
  done
  echo "[OK] $cnt files -> $dest$([[ $DRY -eq 1 ]] && echo " (dry-run)")"
  if [[ $CLEAN -eq 1 ]]; then
    for df in "$dest"/*.md "$dest"/*.sh; do
      [[ -e "$df" ]] || continue
      local bn; bn=$(basename "$df")
      local found=0
      for sf in "${files[@]}"; do
        [[ "$(basename "$sf")" == "$bn" ]] && found=1 && break
      done
      if [[ $found -eq 0 ]]; then
        if [[ $DRY -eq 0 ]]; then rm -f "$df"; fi
        echo "[CLEAN] removed stale $bn"
      fi
    done
  fi
  shopt -u nullglob
}

sync_dir "$SRC/agents/*.md" "$DEST/agents"
sync_dir "$SRC/commands/*.md" "$DEST/commands"

if [[ $DRY -eq 1 ]]; then
  echo "[DRY] would copy scripts/*.sh -> $DEST/scripts"
else
  cp "$SRC"/scripts/*.sh "$DEST/scripts/" 2>/dev/null || true
  chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
  echo "[OK] scripts -> $DEST/scripts"
fi

if command -v opencode >/dev/null 2>&1; then
  if [[ $DRY -eq 1 ]]; then
    echo "[DRY] would validate opencode debug config"
  else
    if opencode debug config >/dev/null 2>&1; then
      echo "[OK] opencode debug config passes"
    else
      echo "[ERR] config invalid — restore backup"; exit 1
    fi
  fi
else
  echo "[WARN] opencode not installed — https://opencode.ai"
fi

echo "[OK] done. Restart opencode (quit + opencode)"
echo "Try: /ship Implement a hello world component"
echo ""
echo "Runtime enforcement (recommended): add to opencode.json:"
echo '  "plugin": ["opencode-autonomy"]'
echo "Then opencode auto-installs updates on startup."
echo ""
echo "Update anytime: npx opencode-autonomy@latest --clean"
