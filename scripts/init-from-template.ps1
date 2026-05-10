#requires -Version 7.0
# Replace `<<PLACEHOLDER>>` tokens across the repo (PowerShell 7+).
# Idempotent — re-running with the same args is a no-op once tokens are gone.

[CmdletBinding()]
param(
  [string]$Name,
  [string]$Desc,
  [string]$Org = 'ECHO-OMEGA-PRIME',
  [string]$Repo,
  [string]$License = 'MIT',
  [string]$Copyright = 'Echo Prime Tech LLC'
)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

function Ask {
  param($label, [ref]$var, $default = $null)
  if (-not $var.Value) {
    $prompt = if ($default) { "$label [$default]" } else { $label }
    $ans = Read-Host -Prompt $prompt
    if (-not $ans -and $default) { $ans = $default }
    $var.Value = $ans
  }
}

Ask 'Project name'         ([ref]$Name)
Ask 'One-line description' ([ref]$Desc)
if (-not $Repo) { $Repo = $Name }
$year = (Get-Date).Year

$replacements = @{
  '<<PROJECT_NAME>>'         = $Name
  '<<ONE_LINE_DESCRIPTION>>' = $Desc
  '<<ORG>>'                  = $Org
  '<<REPO>>'                 = $Repo
  '<<LICENSE>>'              = $License
  '<<COPYRIGHT_HOLDER>>'     = $Copyright
  '<<YEAR>>'                 = "$year"
}

# Walk all text files except .git / node_modules / .venv / this script.
$skipDirs = @('.git', 'node_modules', '.venv', 'venv', 'dist', 'build')
$selfNames = @('init-from-template.sh', 'init-from-template.ps1')

Get-ChildItem -Recurse -File | Where-Object {
  $rel = (Resolve-Path $_.FullName -Relative)
  -not ($skipDirs | Where-Object { $rel -like "*\$_\*" -or $rel -like "*/$_/*" }) `
    -and ($selfNames -notcontains $_.Name)
} | ForEach-Object {
  $path = $_.FullName
  $content = Get-Content -Raw -ErrorAction SilentlyContinue $path
  if ($null -eq $content) { return }
  $orig = $content
  foreach ($k in $replacements.Keys) {
    $content = $content.Replace($k, $replacements[$k])
  }
  if ($content -ne $orig) {
    Set-Content -NoNewline -Path $path -Value $content
  }
}

Write-Host ''
Write-Host '[init] placeholders substituted. Review with: git diff'
Write-Host '[init] then commit: git add -A && git commit -m "chore: instantiate from template"'
