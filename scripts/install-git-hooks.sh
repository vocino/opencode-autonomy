#!/usr/bin/env bash
set -euo pipefail
# Install git hooks that strip AI co-author attribution
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_DIR="$ROOT/.git/hooks"
echo "[INFO] Installing commit-msg hook to strip Cursor co-author trailers..."

mkdir -p "$HOOK_DIR"

cat > "$HOOK_DIR/commit-msg" <<'HOOK'
#!/bin/sh
# commit-msg hook: strip Co-authored-by: Cursor <cursoragent@cursor.com> and any AI attribution
# This prevents AI branding leaking into GitHub history
FILE="$1"
[ -f "$FILE" ] || exit 0

# Remove Cursor's auto-added trailer (case-insensitive)
# Pattern: Co-authored-by: Cursor <cursoragent@cursor.com>
sed -i -E '/^[[:space:]]*Co-authored-by:[[:space:]]*Cursor[[:space:]]*<cursoragent@cursor\.com>/Id' "$FILE"
# Aggressive: any line containing cursoragent@cursor.com
sed -i -E '/cursoragent@cursor\.com/Id' "$FILE"
# Optional: strip other AI co-authors if you want pure human history
# Uncomment next line to also strip Claude/Copilot/ChatGPT attributions
# sed -i -E '/^[[:space:]]*Co-authored-by:[[:space:]]*(Claude|Copilot|ChatGPT|Cursor)/Id' "$FILE"

# Clean up resulting double blank lines at end (keep at most one)
awk '
  { lines[NR]=$0 }
  END {
    # Trim trailing blank lines to single blank
    last=NR
    while (last>1 && lines[last] ~ /^[[:space:]]*$/) last--
    for (i=1;i<=last;i++) print lines[i]
    if (last>0 && last<NR) print ""
  }
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

exit 0
HOOK

chmod +x "$HOOK_DIR/commit-msg"
echo "[OK] Installed $HOOK_DIR/commit-msg"

# Also provide a versioned copy in repo for `core.hooksPath` users
mkdir -p "$ROOT/.githooks"
cp "$HOOK_DIR/commit-msg" "$ROOT/.githooks/commit-msg"
echo "[OK] Copied to $ROOT/.githooks/commit-msg (for core.hooksPath)"

echo ""
echo "To enable for all clones, run:"
echo "  git config core.hooksPath .githooks"
echo "Or just keep .git/hooks/commit-msg active locally."
