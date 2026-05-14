#!/usr/bin/env bash
# Clone-to-running-in-5-min for <<PROJECT_NAME>>.
#
# Idempotent: re-running is safe. Detects available toolchains and installs
# only what's missing. Prints the final RUN: command at the end.
#
# Supports: Node (npm/pnpm/yarn/bun), Python (pip/poetry/uv), Rust, Go,
#           Docker Compose. Pre-flight: git-lfs, direnv reminder.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log()  { printf '\033[1;36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup]\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[1;32m[setup]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[setup]\033[0m %s\n' "$*" >&2; exit 1; }

cmd() { command -v "$1" >/dev/null 2>&1; }

# ─── pre-flight: git-lfs ───
if cmd git && git lfs version >/dev/null 2>&1; then
  if [ -f .gitattributes ] && grep -q "filter=lfs" .gitattributes 2>/dev/null; then
    git lfs pull
    log "git-lfs assets pulled"
  fi
elif [ -f .gitattributes ] && grep -q "filter=lfs" .gitattributes 2>/dev/null; then
  warn "git-lfs not installed but repo uses it — run: git lfs install"
fi

# ─── envrc ───
if [ ! -f .envrc ] && [ -f .envrc.example ]; then
  cp .envrc.example .envrc
  log "created .envrc from .envrc.example — fill in values before running"
fi
if [ -f .envrc ] && cmd direnv; then
  direnv allow . 2>/dev/null || true
fi

INSTALLED_ANY=0

# ─── Node ───
if [ -f package.json ]; then
  # Prefer the lockfile-implied package manager; fall back in order.
  if [ -f bun.lockb ] && cmd bun; then
    log "node/bun project — bun install"
    bun install
  elif [ -f pnpm-lock.yaml ] && cmd pnpm; then
    log "node/pnpm project — pnpm install --frozen-lockfile"
    pnpm install --frozen-lockfile
  elif [ -f yarn.lock ] && cmd yarn; then
    log "node/yarn project — yarn install --frozen-lockfile"
    yarn install --frozen-lockfile
  else
    cmd npm || err "npm not found — install Node 20+"
    if [ -f package-lock.json ]; then
      log "node/npm project — npm ci"
      npm ci
    else
      log "node/npm project — npm install"
      npm install
    fi
  fi
  INSTALLED_ANY=1
fi

# ─── Python ───
if [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
  cmd python3 || err "python3 not found"

  if [ -f pyproject.toml ] && cmd uv; then
    # uv is fastest; honours pyproject.toml + uv.lock
    log "python/uv project — uv sync"
    uv sync
    INSTALLED_ANY=1
  elif [ -f pyproject.toml ] && cmd poetry; then
    log "python/poetry project — poetry install"
    poetry install
    INSTALLED_ANY=1
  else
    # venv fallback
    if [ ! -d .venv ]; then
      python3 -m venv .venv
      log "created .venv"
    fi
    # shellcheck disable=SC1091
    . .venv/bin/activate
    python3 -m pip install --upgrade pip -q
    if [ -f pyproject.toml ]; then
      pip install -e ".[dev]" -q 2>/dev/null || pip install -e . -q
    elif [ -f requirements.txt ]; then
      pip install -r requirements.txt -q
    elif [ -f setup.py ]; then
      pip install -e . -q
    fi
    INSTALLED_ANY=1
  fi
fi

# ─── Rust ───
if [ -f Cargo.toml ]; then
  cmd cargo || err "cargo not found — install rustup: https://rustup.rs"
  log "rust project — cargo build"
  cargo build
  INSTALLED_ANY=1
fi

# ─── Go ───
if [ -f go.mod ]; then
  cmd go || err "go not found — https://go.dev/dl"
  log "go project — go build ./..."
  go build ./...
  INSTALLED_ANY=1
fi

# ─── Docker Compose ───
if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
  if cmd docker && docker compose version >/dev/null 2>&1; then
    log "docker compose found — pulling images"
    docker compose pull --quiet 2>/dev/null || true
    INSTALLED_ANY=1
  elif cmd docker-compose; then
    docker-compose pull --quiet 2>/dev/null || true
    INSTALLED_ANY=1
  else
    warn "docker-compose.yml found but docker not available — skipping"
  fi
fi

if [ "$INSTALLED_ANY" -eq 0 ]; then
  warn "no language manifest detected — nothing to install"
fi

# ─── detect RUN command ───
RUN_CMD="<<INSERT YOUR RUN COMMAND HERE>>"

# Try package.json scripts.dev → scripts.start → scripts.serve
if [ -f package.json ] && cmd node; then
  for script in dev start serve; do
    if node -e "process.exit(require('./package.json').scripts?.['$script'] ? 0 : 1)" 2>/dev/null; then
      RUN_CMD="npm run $script"
      break
    fi
  done
  # bun / pnpm prefix
  if [ -f bun.lockb ] && cmd bun && [[ "$RUN_CMD" == npm* ]]; then
    RUN_CMD="${RUN_CMD/npm/bun}"
  elif [ -f pnpm-lock.yaml ] && cmd pnpm && [[ "$RUN_CMD" == npm* ]]; then
    RUN_CMD="${RUN_CMD/npm run/pnpm}"
  fi
fi

# Python fallback
if [[ "$RUN_CMD" == "<<"* ]]; then
  if [ -f pyproject.toml ]; then
    _pkg=$(python3 -c "
import sys
try:
  import tomllib
  with open('pyproject.toml','rb') as f: d=tomllib.load(f)
  print(d.get('project',{}).get('name',''))
except: pass" 2>/dev/null || true)
    if [ -n "$_pkg" ]; then
      if cmd uv; then
        RUN_CMD="uv run python -m $_pkg"
      else
        RUN_CMD="python -m $_pkg"
      fi
    fi
  fi
fi

# Makefile fallback
if [[ "$RUN_CMD" == "<<"* ]] && [ -f Makefile ]; then
  for target in dev run serve start; do
    if grep -q "^$target:" Makefile 2>/dev/null; then
      RUN_CMD="make $target"
      break
    fi
  done
fi

# ─── direnv reminder ───
if [ -f .envrc ] && ! cmd direnv; then
  warn "direnv not installed — run 'source .envrc' manually or install direnv"
fi

ok "setup complete"
printf '\n'
printf '  \033[1;32mRUN:\033[0m %s\n' "$RUN_CMD"
printf '\n'
