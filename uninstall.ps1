# Hermes Agent Docker Uninstaller for Windows PowerShell
# Usage:
#   .\uninstall.ps1
#   .\uninstall.ps1 -RemoveData
#   .\uninstall.ps1 -RemoveFiles -RemoveData

param(
  [string]$InstallDir = "$env:USERPROFILE\.hermes-docker",
  [switch]$RemoveFiles,
  [switch]$RemoveData
)

$ErrorActionPreference = 'Stop'

function Log($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }
function Die($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Test-Command($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

Log "Hermes Docker Uninstaller for Windows"

# Check if install directory exists
if (-not (Test-Path $InstallDir)) {
  Warn "Hermes Docker install directory not found: $InstallDir"
  Warn "Nothing to uninstall."
  exit 0
}

# Check Docker availability
$dockerAvailable = $true
if (-not (Test-Command 'docker')) {
  Warn "Docker not found. Skipping Docker stack teardown."
  $dockerAvailable = $false
} else {
  docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    Warn "Docker daemon is not running. Skipping Docker stack teardown."
    Warn "Start Docker Desktop first, or remove manually."
    $dockerAvailable = $false
  }
}

# Stop and remove the Docker stack
if ($dockerAvailable) {
  Push-Location $InstallDir
  Log "Stopping Hermes Docker stack..."
  if ($RemoveData) {
    docker compose down -v --remove-orphans
    Ok "Stopped stack and removed data volumes."
  } else {
    docker compose down --remove-orphans
    Ok "Stopped stack. Data volumes preserved."
    Write-Host "  To remove data: .\uninstall.ps1 -RemoveData"
  }
  Pop-Location
}

# Remove files if requested
if ($RemoveFiles) {
  Log "Removing install directory..."
  Remove-Item -Recurse -Force $InstallDir
  Ok "Removed: $InstallDir"
} else {
  Write-Host ""
  Write-Host "Files kept at: $InstallDir"
  Write-Host "To remove files: .\uninstall.ps1 -RemoveFiles"
  if ($dockerAvailable) {
    Write-Host "To also remove data: .\uninstall.ps1 -RemoveFiles -RemoveData"
  }
}

Ok "Uninstall complete."
