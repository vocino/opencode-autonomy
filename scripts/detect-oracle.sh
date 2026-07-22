#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$(pwd)}"

if [[ ! -d "$ROOT_DIR" ]]; then
  printf 'error: directory not found: %s\n' "$ROOT_DIR" >&2
  exit 1
fi

cd "$ROOT_DIR"

declare -a ORACLE_COMMANDS=()

add_oracle() {
  local candidate="$1"
  local existing=""

  if [[ -z "$candidate" ]]; then
    return 0
  fi

  for existing in "${ORACLE_COMMANDS[@]}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done

  ORACLE_COMMANDS+=("$candidate")
}

has_package_script() {
  local script_name="$1"

  if [[ ! -f package.json ]]; then
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -e --arg script "$script_name" '.scripts[$script] != null' package.json >/dev/null 2>&1
    return $?
  fi

  rg -q "\"${script_name}\"[[:space:]]*:" package.json
}

if [[ -f package.json ]]; then
  if has_package_script "lint"; then
    add_oracle "npm run lint"
  fi
  if has_package_script "typecheck"; then
    add_oracle "npm run typecheck"
  elif has_package_script "types"; then
    add_oracle "npm run types"
  fi
  if has_package_script "test"; then
    add_oracle "npm test"
  elif has_package_script "test:ci"; then
    add_oracle "npm run test:ci"
  fi
  if has_package_script "build"; then
    add_oracle "npm run build"
  fi
fi

if [[ -f pyproject.toml ]]; then
  if rg -q "\[tool\.ruff" pyproject.toml; then
    add_oracle "uv run ruff check ."
  fi
  if rg -q "\[tool\.mypy" pyproject.toml; then
    add_oracle "uv run mypy ."
  fi
  if rg -q "\[tool\.pytest" pyproject.toml || rg -q "pytest" pyproject.toml; then
    add_oracle "uv run pytest"
  fi
fi

if [[ -f Makefile ]]; then
  if rg -q "^lint:" Makefile; then
    add_oracle "make lint"
  fi
  if rg -q "^test:" Makefile; then
    add_oracle "make test"
  fi
  if rg -q "^build:" Makefile; then
    add_oracle "make build"
  fi
fi

if [[ -f Cargo.toml ]]; then
  add_oracle "cargo test"
  add_oracle "cargo clippy --all-targets --all-features -- -D warnings"
fi

if [[ -f go.mod ]]; then
  add_oracle "go test ./..."
fi

# Repo-level fallback checks
if [[ -f install.sh ]]; then
  add_oracle "shellcheck install.sh"
fi

if [[ -f scripts/detect-oracle.sh ]]; then
  add_oracle "shellcheck scripts/detect-oracle.sh"
fi

if [[ -f tests/validate.sh ]]; then
  add_oracle "bash tests/validate.sh"
fi

if [[ -f opencode.json.example ]] && command -v jq >/dev/null 2>&1; then
  add_oracle "jq empty opencode.json.example"
fi

if [[ -f opencode.json.minimal.example ]] && command -v jq >/dev/null 2>&1; then
  add_oracle "jq empty opencode.json.minimal.example"
fi

if ((${#ORACLE_COMMANDS[@]} == 0)); then
  printf '%s\n' "echo 'No oracle commands detected. Add command checks to 02-dod.md.'"
  exit 0
fi

printf '%s\n' "${ORACLE_COMMANDS[@]}"
