#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-$(pwd)}"; cd "$ROOT"
declare -a ORACLES=()

add() { [[ -z "${1:-}" ]] && return 0; for e in "${ORACLES[@]}"; do [[ "$e" == "$1" ]] && return 0; done; ORACLES+=("$1"); }

has_script() {
  [[ -f package.json ]] || return 1
  if command -v jq >/dev/null; then jq -e --arg s "$1" '.scripts[$s] != null' package.json >/dev/null 2>&1
  else grep -q "\"$1\"" package.json
  fi
}

if [[ -f package.json ]]; then
  has_script lint && add "npm run lint"
  has_script typecheck && add "npm run typecheck" || has_script types && add "npm run types"
  has_script test && add "npm test" || has_script test:ci && add "npm run test:ci"
  has_script build && add "npm run build"
fi

[[ -f pyproject.toml ]] && { grep -q "ruff\|pytest\|mypy" pyproject.toml && { add "uv run ruff check ."; add "uv run mypy ."; add "uv run pytest"; }; }
[[ -f Makefile ]] && { grep -q "^lint:" Makefile && add "make lint"; grep -q "^test:" Makefile && add "make test"; grep -q "^build:" Makefile && add "make build"; }
[[ -f Cargo.toml ]] && { add "cargo test"; add "cargo clippy --all-targets --all-features -- -D warnings"; }
[[ -f go.mod ]] && add "go test ./..."

# repo self-checks
[[ -f install.sh ]] && add "shellcheck install.sh"
[[ -f scripts/detect-oracle.sh ]] && add "shellcheck scripts/detect-oracle.sh"
[[ -f tests/validate.sh ]] && add "bash tests/validate.sh"
[[ -f opencode.json.example ]] && command -v jq >/dev/null && add "jq empty opencode.json.example"

(( ${#ORACLES[@]} == 0 )) && { echo "echo 'No oracle commands detected'"; exit 0; }
printf '%s\n' "${ORACLES[@]}"
