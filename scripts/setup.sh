#!/usr/bin/env bash
# Clone-to-running-in-5-min for <<PROJECT_NAME>>.
#
# Idempotent: re-running is safe. Detects available toolchains and installs
# only what's missing. Prints the final RUN: command at the end.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log() { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[setup]\033[0m %s\n' "$*" >&2; }

# ─── envrc ───
if [ ! -f .envrc ] && [ -f .envrc.example ]; then
  cp .envrc.example .envrc
  log "created .envrc from .envrc.example — fill in values before running"
fi

INSTALLED_ANY=0

# ─── Node ───
if [ -f package.json ]; then
  command -v npm >/dev/null 2>&1 || { err "npm not found — install Node 20+"; exit 1; }
  log "node project detected — npm ci"
  npm ci
  INSTALLED_ANY=1
fi

# ─── Python ───
if [ -f pyproject.toml ] || [ -f requirements.txt ]; then
  command -v python3 >/dev/null 2>&1 || { err "python3 not found"; exit 1; }
  if [ ! -d .venv ]; then
    python3 -m venv .venv
    log "created .venv"
  fi
  # shellcheck disable=SC1091
  . .venv/bin/activate
  if [ -f pyproject.toml ]; then
    pip install -e ".[dev]" 2>/dev/null || pip install -e .
  elif [ -f requirements.txt ]; then
    pip install -r requirements.txt
  fi
  INSTALLED_ANY=1
fi

# ─── Rust ───
if [ -f Cargo.toml ]; then
  command -v cargo >/dev/null 2>&1 || { err "cargo not found — install rustup"; exit 1; }
  log "rust project detected — cargo build"
  cargo build
  INSTALLED_ANY=1
fi

# ─── Go ───
if [ -f go.mod ]; then
  command -v go >/dev/null 2>&1 || { err "go not found"; exit 1; }
  log "go project detected — go build ./..."
  go build ./...
  INSTALLED_ANY=1
fi

if [ "$INSTALLED_ANY" -eq 0 ]; then
  warn "no language manifest detected — nothing to install"
fi

cat <<EOF

[setup] done. Next:

  RUN: <<INSERT YOUR RUN COMMAND HERE — e.g. 'npm run dev' or 'python -m <<PROJECT_NAME>>'>>

EOF
