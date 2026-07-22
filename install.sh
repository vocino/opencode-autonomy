#!/usr/bin/env bash
set -euo pipefail

# opencode-autonomy installer — trivial, verifiable, bloat-free
# --clean: delete stale .md/.sh in dest not in repo + prune backups to 3

CLEAN=0; KEEP=3
if [[ "${1:-}" == "--clean" ]]; then CLEAN=1; fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/scripts"

echo "[INFO] $SRC -> $DEST (clean=$CLEAN)"

if [[ -f "$DEST/opencode.json" ]]; then
  cp "$DEST/opencode.json" "$DEST/opencode.json.bak.$(date +%s)"
  if [[ $CLEAN -eq 1 ]]; then
    ls -t "$DEST"/opencode.json.bak.* 2>/dev/null | tail -n +$((KEEP+1)) | xargs -r rm -f || true
  fi
fi

if [[ ! -f "$DEST/opencode.json" ]]; then
  cp "$SRC/opencode.json.example" "$DEST/opencode.json"
  echo "[OK] created opencode.json from example"
else
  if command -v jq >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq -s '
      .[0] as $old | .[1] as $ex |
      ($old|{model,small_model,provider}) as $user |
      ($ex|{subagent_depth,snapshot,formatter,lsp,tool_output,compaction,experimental,permission,agent}) as $auto |
      ($old * $auto) * $user | .model //= $ex.model | .small_model //= $ex.small_model
    ' "$DEST/opencode.json" "$SRC/opencode.json.example" > "$tmp" && mv "$tmp" "$DEST/opencode.json"
    echo "[OK] merged autonomy keys (preserved model/provider)"
  else
    echo "[WARN] jq missing — skipping merge"
  fi
fi

sync_dir() {
  local pattern="$1" dest="$2"
  local cnt=0
  shopt -s nullglob
  local files=($pattern)
  for f in "${files[@]}"; do
    cp "$f" "$dest/"
    cnt=$((cnt+1))
  done
  echo "[OK] $cnt files -> $dest"
  if [[ $CLEAN -eq 1 ]]; then
    for df in "$dest"/*.md "$dest"/*.sh; do
      [[ -e "$df" ]] || continue
      local bn; bn=$(basename "$df")
      local found=0
      for sf in "${files[@]}"; do
        [[ "$(basename "$sf")" == "$bn" ]] && found=1 && break
      done
      if [[ $found -eq 0 ]]; then
        rm -f "$df"
        echo "[CLEAN] removed stale $bn"
      fi
    done
  fi
  shopt -u nullglob
}

sync_dir "$SRC/agents/*.md" "$DEST/agents"
sync_dir "$SRC/commands/*.md" "$DEST/commands"

cp "$SRC"/scripts/*.sh "$DEST/scripts/" 2>/dev/null || true
chmod +x "$DEST/scripts/"*.sh 2>/dev/null || true
echo "[OK] scripts -> $DEST/scripts"

if command -v opencode >/dev/null 2>&1; then
  if opencode debug config >/dev/null 2>&1; then
    echo "[OK] opencode debug config passes"
  else
    echo "[ERR] config invalid — restore backup"; exit 1
  fi
else
  echo "[WARN] opencode not installed — https://opencode.ai"
fi

echo "[OK] done. Restart opencode (quit + opencode)"
echo "Try: /ship Implement a hello world component"
