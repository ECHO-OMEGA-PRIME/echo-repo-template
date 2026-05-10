#requires -Version 7.0
# Clone-to-running-in-5-min for <<PROJECT_NAME>> (PowerShell 7+).
#
# Idempotent: re-running is safe. Detects available toolchains and installs
# only what's missing. Prints the final RUN: command at the end.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Log  { param($m) Write-Host "[setup] $m" -ForegroundColor Cyan }
function Warn { param($m) Write-Host "[setup] $m" -ForegroundColor Yellow }
function Die  { param($m) Write-Host "[setup] $m" -ForegroundColor Red; exit 1 }

# --- envrc ---
if (-not (Test-Path .envrc) -and (Test-Path .envrc.example)) {
  Copy-Item .envrc.example .envrc
  Log "created .envrc from .envrc.example - fill in values before running"
}

$installedAny = $false

# --- Node ---
if (Test-Path package.json) {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { Die 'npm not found - install Node 20+' }
  Log "node project detected - npm ci"
  & npm ci
  if ($LASTEXITCODE -ne 0) { Die "npm ci failed" }
  $installedAny = $true
}

# --- Python ---
if ((Test-Path pyproject.toml) -or (Test-Path requirements.txt)) {
  $py = Get-Command python -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command python3 -ErrorAction SilentlyContinue }
  if (-not $py) { Die 'python not found' }
  if (-not (Test-Path .venv)) {
    & $py.Path -m venv .venv
    Log "created .venv"
  }
  $venvPy = Join-Path '.venv' (if ($IsWindows) { 'Scripts/python.exe' } else { 'bin/python' })
  if (Test-Path pyproject.toml) {
    & $venvPy -m pip install -e '.[dev]'
    if ($LASTEXITCODE -ne 0) { & $venvPy -m pip install -e . }
  } elseif (Test-Path requirements.txt) {
    & $venvPy -m pip install -r requirements.txt
  }
  $installedAny = $true
}

# --- Rust ---
if (Test-Path Cargo.toml) {
  if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { Die 'cargo not found - install rustup' }
  Log "rust project detected - cargo build"
  & cargo build
  if ($LASTEXITCODE -ne 0) { Die "cargo build failed" }
  $installedAny = $true
}

# --- Go ---
if (Test-Path go.mod) {
  if (-not (Get-Command go -ErrorAction SilentlyContinue)) { Die 'go not found' }
  Log "go project detected - go build ./..."
  & go build ./...
  if ($LASTEXITCODE -ne 0) { Die "go build failed" }
  $installedAny = $true
}

if (-not $installedAny) { Warn "no language manifest detected - nothing to install" }

@"

[setup] done. Next:

  RUN: <<INSERT YOUR RUN COMMAND HERE - e.g. 'npm run dev' or 'python -m <<PROJECT_NAME>>'>>

"@
