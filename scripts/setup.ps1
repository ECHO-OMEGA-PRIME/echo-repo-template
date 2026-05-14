#requires -Version 7.0
# Clone-to-running-in-5-min for <<PROJECT_NAME>> (PowerShell 7+).
#
# Idempotent: re-running is safe. Detects available toolchains and installs
# only what's missing. Prints the final RUN: command at the end.
#
# Supports: Node (npm/pnpm/yarn/bun), Python (pip/poetry/uv), Rust, Go,
#           Docker Compose. Pre-flight: git-lfs, direnv reminder.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Log  { param($m) Write-Host "[setup] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[setup] $m" -ForegroundColor Yellow }
function Ok   { param($m) Write-Host "[setup] $m" -ForegroundColor Green }
function Die  { param($m) Write-Host "[setup] ERROR: $m" -ForegroundColor Red; exit 1 }
function Cmd  { param($n) $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }

# --- pre-flight: git-lfs ---
if ((Cmd 'git') -and (& git lfs version 2>$null)) {
  if ((Test-Path .gitattributes) -and (Select-String -Path .gitattributes -Pattern 'filter=lfs' -Quiet)) {
    & git lfs pull
    Log "git-lfs assets pulled"
  }
} elseif ((Test-Path .gitattributes) -and (Select-String -Path .gitattributes -Pattern 'filter=lfs' -Quiet)) {
  Warn "git-lfs not installed but repo uses it — run: git lfs install"
}

# --- envrc ---
if (-not (Test-Path .envrc) -and (Test-Path .envrc.example)) {
  Copy-Item .envrc.example .envrc
  Log "created .envrc from .envrc.example — fill in values before running"
}
if ((Test-Path .envrc) -and (Cmd 'direnv')) {
  & direnv allow . 2>$null
}

$installedAny = $false

# --- Node ---
if (Test-Path package.json) {
  if ((Test-Path 'bun.lockb') -and (Cmd 'bun')) {
    Log "node/bun project — bun install"
    & bun install; if ($LASTEXITCODE -ne 0) { Die "bun install failed" }
  } elseif ((Test-Path 'pnpm-lock.yaml') -and (Cmd 'pnpm')) {
    Log "node/pnpm project — pnpm install --frozen-lockfile"
    & pnpm install --frozen-lockfile; if ($LASTEXITCODE -ne 0) { Die "pnpm install failed" }
  } elseif ((Test-Path 'yarn.lock') -and (Cmd 'yarn')) {
    Log "node/yarn project — yarn install --frozen-lockfile"
    & yarn install --frozen-lockfile; if ($LASTEXITCODE -ne 0) { Die "yarn install failed" }
  } else {
    if (-not (Cmd 'npm')) { Die "npm not found — install Node 20+" }
    if (Test-Path 'package-lock.json') {
      Log "node/npm project — npm ci"
      & npm ci; if ($LASTEXITCODE -ne 0) { Die "npm ci failed" }
    } else {
      Log "node/npm project — npm install"
      & npm install; if ($LASTEXITCODE -ne 0) { Die "npm install failed" }
    }
  }
  $installedAny = $true
}

# --- Python ---
if ((Test-Path pyproject.toml) -or (Test-Path requirements.txt) -or (Test-Path setup.py)) {
  $py = Get-Command python -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
  if (-not $py) { Die "python not found" }

  if ((Test-Path pyproject.toml) -and (Cmd 'uv')) {
    Log "python/uv project — uv sync"
    & uv sync; if ($LASTEXITCODE -ne 0) { Die "uv sync failed" }
    $installedAny = $true
  } elseif ((Test-Path pyproject.toml) -and (Cmd 'poetry')) {
    Log "python/poetry project — poetry install"
    & poetry install; if ($LASTEXITCODE -ne 0) { Die "poetry install failed" }
    $installedAny = $true
  } else {
    $venvDir = '.venv'
    if (-not (Test-Path $venvDir)) {
      & $py.Path -m venv $venvDir
      Log "created .venv"
    }
    $venvPy = Join-Path $venvDir (if ($IsWindows) { 'Scripts/python.exe' } else { 'bin/python' })
    & $venvPy -m pip install --upgrade pip -q
    if (Test-Path pyproject.toml) {
      & $venvPy -m pip install -e '.[dev]' -q
      if ($LASTEXITCODE -ne 0) { & $venvPy -m pip install -e . -q }
    } elseif (Test-Path requirements.txt) {
      & $venvPy -m pip install -r requirements.txt -q
      if ($LASTEXITCODE -ne 0) { Die "pip install -r requirements.txt failed" }
    } elseif (Test-Path setup.py) {
      & $venvPy -m pip install -e . -q
      if ($LASTEXITCODE -ne 0) { Die "pip install -e . failed" }
    }
    $installedAny = $true
  }
}

# --- Rust ---
if (Test-Path Cargo.toml) {
  if (-not (Cmd 'cargo')) { Die "cargo not found — install rustup: https://rustup.rs" }
  Log "rust project — cargo build"
  & cargo build; if ($LASTEXITCODE -ne 0) { Die "cargo build failed" }
  $installedAny = $true
}

# --- Go ---
if (Test-Path go.mod) {
  if (-not (Cmd 'go')) { Die "go not found — https://go.dev/dl" }
  Log "go project — go build ./..."
  & go build ./...; if ($LASTEXITCODE -ne 0) { Die "go build failed" }
  $installedAny = $true
}

# --- Docker Compose ---
$composeFile = (Test-Path 'docker-compose.yml') -or (Test-Path 'compose.yml')
if ($composeFile) {
  if (Cmd 'docker') {
    $dcVersion = & docker compose version 2>$null
    if ($LASTEXITCODE -eq 0) {
      Log "docker compose — pulling images"
      & docker compose pull --quiet 2>$null
      $installedAny = $true
    }
  } elseif (Cmd 'docker-compose') {
    & docker-compose pull --quiet 2>$null
    $installedAny = $true
  } else {
    Warn "docker-compose.yml found but docker not available — skipping"
  }
}

if (-not $installedAny) { Warn "no language manifest detected — nothing to install" }

# --- detect RUN command ---
$runCmd = "<<INSERT YOUR RUN COMMAND HERE>>"

if (Test-Path package.json) {
  $pkg = Get-Content package.json -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
  foreach ($s in @('dev','start','serve')) {
    if ($pkg.scripts.$s) {
      $runner = 'npm run'
      if ((Test-Path 'bun.lockb') -and (Cmd 'bun'))         { $runner = 'bun run' }
      elseif ((Test-Path 'pnpm-lock.yaml') -and (Cmd 'pnpm')) { $runner = 'pnpm' }
      elseif ((Test-Path 'yarn.lock') -and (Cmd 'yarn'))     { $runner = 'yarn' }
      $runCmd = "$runner $s"
      break
    }
  }
}

if ($runCmd -like '<<*') {
  if (Test-Path pyproject.toml) {
    try {
      # Require Python 3.11+ for tomllib; fall back to grep
      $pkgName = & python -c "import tomllib,sys; d=tomllib.load(open('pyproject.toml','rb')); print(d.get('project',{}).get('name',''))" 2>$null
      if ($pkgName) {
        if (Cmd 'uv') { $runCmd = "uv run python -m $pkgName" }
        else           { $runCmd = "python -m $pkgName" }
      }
    } catch {}
  }
}

if (($runCmd -like '<<*') -and (Test-Path Makefile)) {
  foreach ($t in @('dev','run','serve','start')) {
    if (Select-String -Path Makefile -Pattern "^${t}:" -Quiet) {
      $runCmd = "make $t"
      break
    }
  }
}

# --- direnv reminder ---
if ((Test-Path .envrc) -and (-not (Cmd 'direnv'))) {
  Warn "direnv not installed — load .envrc manually or install direnv"
}

Ok "setup complete"
Write-Host ""
Write-Host "  RUN: $runCmd" -ForegroundColor Green
Write-Host ""
