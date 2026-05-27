# Hermes Agent Docker Public Installer for Windows PowerShell
# Requires Docker Desktop with WSL2 backend enabled.
# Usage:
#   .\install.ps1
#   .\install.ps1 -Provider openrouter -Model deepseek/deepseek-v4-flash:free -OpenRouterApiKey sk-...

param(
  [string]$InstallDir = "$env:USERPROFILE\.hermes-docker",
  [ValidateSet('openrouter','anthropic','openai','google','deepseek','custom')]
  [string]$Provider = 'openrouter',
  [string]$Model = 'deepseek/deepseek-v4-flash:free',
  [int]$Port = 8642,
  [string]$ProjectName = 'hermes-agent',
  [switch]$NoStart,
  [switch]$Browser,
  [switch]$SkipBuild,
  [switch]$Force,
  [switch]$Uninstall,
  [string]$HermesVersion = $(if ($env:HERMES_VERSION) { $env:HERMES_VERSION } else { 'main' }),
  [string]$OpenRouterApiKey = $env:OPENROUTER_API_KEY,
  [string]$AnthropicApiKey = $env:ANTHROPIC_API_KEY,
  [string]$OpenAIApiKey = $env:OPENAI_API_KEY,
  [string]$GoogleApiKey = $env:GOOGLE_API_KEY,
  [string]$DeepSeekApiKey = $env:DEEPSEEK_API_KEY,
  [string]$CustomApiKey = $env:CUSTOM_API_KEY,
  [string]$CustomBaseUrl = $env:CUSTOM_BASE_URL,
  [string]$ApiServerKey = $env:API_SERVER_KEY
)

$ErrorActionPreference = 'Stop'

function Log($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "WARN: $msg" -ForegroundColor Yellow }
function Die($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Test-Command($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

function Get-DockerDesktopPath() {
  $paths = @(
    "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
    "$env:ProgramFiles (x86)\Docker\Docker\Docker Desktop.exe",
    "$env:LocalAppData\Programs\Docker\Docker\Docker Desktop.exe"
  )
  foreach ($path in $paths) {
    if (Test-Path $path) { return $path }
  }
  return $null
}

function Ensure-Docker() {
  if (Test-Command 'docker') {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { Ok 'Docker is ready'; return }

    Log 'Docker is installed but not running. Attempting to start Docker Desktop...'
    $desktopExe = Get-DockerDesktopPath
    if (-not $desktopExe) {
      Die 'Docker CLI exists but Docker Desktop executable was not found. Start Docker Desktop manually or reinstall it, then rerun the installer.'
    }

    Start-Process $desktopExe
    Log 'Waiting for Docker Desktop to start (up to 2 minutes)...'
    for ($i=0; $i -lt 30; $i++) {
      docker info *> $null
      if ($LASTEXITCODE -eq 0) { Ok 'Docker is ready'; return }
      Start-Sleep -Seconds 4
    }
    Die 'Docker Desktop failed to start. Open it manually and rerun the installer.'
  }

  Log 'Docker is not installed. Attempting to install Docker Desktop...'

  if (Test-Command 'winget') {
    Log 'Installing Docker Desktop via winget...'
    try {
      $wingetProcess = Start-Process winget -ArgumentList @('install', 'Docker.DockerDesktop', '--silent', '--accept-package-agreements', '--accept-source-agreements') -NoNewWindow -Wait -PassThru
      if ($wingetProcess.ExitCode -eq 0) {
        Ok 'Docker Desktop installation completed via winget.'
      } else {
        Warn "winget exit code: $($wingetProcess.ExitCode). Attempting manual download fallback..."
      }
    } catch {
      Warn 'winget installation failed. Falling back to manual download...'
    }
  }

  if (-not (Test-Command 'docker')) {
    Log 'Downloading Docker Desktop installer...'
    $url = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
    $installer = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
    try {
      Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
      Log 'Running Docker Desktop installer silently...'
      $installerProcess = Start-Process $installer -ArgumentList @('install', '--quiet', '--accept-license') -NoNewWindow -Wait -PassThru
      if ($installerProcess.ExitCode -eq 0) {
        Ok 'Docker Desktop installation completed successfully.'
      } else {
        Die "Installer exit code: $($installerProcess.ExitCode). Install Docker Desktop manually: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
      }
    } catch {
      Die 'Failed to download/install Docker. Please install manually: https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
    } finally {
      if (Test-Path $installer) { Remove-Item $installer -Force -ErrorAction SilentlyContinue }
    }
  }

  $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
  $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$machinePath;$userPath"

  if (-not (Test-Command 'docker')) {
    Die 'Docker installed but not found in PATH. Please restart your PowerShell session and run the installer again.'
  }

  Log 'Starting Docker Desktop...'
  $desktopExe = Get-DockerDesktopPath
  if (-not $desktopExe) {
    Die 'Docker Desktop was installed but its executable could not be found. Start it manually or reinstall Docker Desktop, then rerun the installer.'
  }
  Start-Process $desktopExe

  Log 'Waiting for Docker to be ready (up to 3 minutes)...'
  for ($i=0; $i -lt 45; $i++) {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { Ok 'Docker is ready'; return }
    Start-Sleep -Seconds 4
  }

  Die 'Docker Desktop installed but failed to respond. Please start it manually and rerun the installer.'
}

function New-SecretHex() {
  $bytes = New-Object byte[] 24
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Safe-Write($Path, $Content) {
  if ((Test-Path $Path) -and -not $Force) {
    Warn "Keeping existing $Path. Use -Force to overwrite."
    return
  }
  $parent = Split-Path $Path -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Test-PortInUse([int]$Port) {
  try {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    return [bool]$conn
  } catch { return $false }
}

function Resolve-Port() {
  if (Test-PortInUse $Port) {
    Warn "Port $Port is already in use."
    foreach ($candidate in @(8643,8644,18642,28642)) {
      if (-not (Test-PortInUse $candidate)) {
        $ans = Read-Host "Use free port $candidate instead? [Y/n]"
        if (-not $ans -or $ans -match '^(y|yes)$') { $script:Port = $candidate; Ok "Using port $Port"; return }
      }
    }
    Die "Choose a free port with -Port <port>."
  }
}

function Wait-Health() {
  $url = "http://127.0.0.1:$Port/health"
  Log "Waiting for Hermes API healthcheck: $url"
  for ($i=0; $i -lt 60; $i++) {
    try { Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 | Out-Null; Ok 'Hermes API server is healthy'; return } catch { Start-Sleep -Seconds 2 }
  }
  Warn 'Healthcheck did not pass within 120 seconds. Showing recent logs:'
  docker compose logs --tail 80 hermes
}

# ── Preflight ──────────────────────────────────────────────────

Log 'Hermes Docker Installer for Windows'

$CanValidateCompose = $false
if ($SkipBuild) {
  Log '--skip-build: skipping Docker checks and build.'
  if (Test-Command 'docker') {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) {
      docker compose version *> $null
      if ($LASTEXITCODE -eq 0) {
        $CanValidateCompose = $true
        Ok 'Docker is ready, will validate Compose config.'
      } else {
        Warn 'Docker is running but Docker Compose v2 is not available; will skip Compose config validation.'
      }
    } else {
      Warn 'Docker is installed but daemon is not available; will skip Compose config validation.'
    }
  } else {
    Warn 'Docker is not available; will skip Compose config validation.'
  }
} else {
  Ensure-Docker
  $CanValidateCompose = $true
}

# ── Uninstall ───────────────────────────────────────────────────

if ($Uninstall) {
  if (-not (Test-Path $InstallDir)) {
    Warn "Install directory not found: $InstallDir"
    Warn 'Nothing to uninstall.'
    exit 0
  }

  $dockerAvailable = $false
  if (Test-Command 'docker') {
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { $dockerAvailable = $true }
    else { Warn 'Docker daemon is not running. Skipping stack shutdown.' }
  } else {
    Warn 'Docker not found. Skipping stack shutdown.'
  }

  if ($dockerAvailable) {
    Push-Location $InstallDir
    docker compose down --remove-orphans *> $null
    Log "Stack stopped. Files kept at: $InstallDir"
    $ans = Read-Host 'Remove data volume too? (y/N)'
    if ($ans -match '^(y|yes)$') { docker compose down -v --remove-orphans; Ok 'Removed stack and data volume' }
    else { Ok 'Removed stack, kept data volume' }
    Pop-Location
  } else {
    Warn "Files kept at: $InstallDir"
  }
  exit 0
}

# ── Interactive setup ───────────────────────────────────────────

if (-not $PSBoundParameters.ContainsKey('Provider')) {
  Write-Host ''
  Write-Host 'Choose your model provider:'
  Write-Host '  1) OpenRouter  recommended, many models'
  Write-Host '  2) Anthropic'
  Write-Host '  3) OpenAI'
  Write-Host '  4) Google Gemini'
  Write-Host '  5) DeepSeek'
  Write-Host '  6) Custom OpenAI-compatible endpoint'
  $choice = Read-Host 'Provider [1]'
  if (-not $choice) { $choice = '1' }
  switch ($choice) {
    '1' { $Provider='openrouter'; if (-not $PSBoundParameters.ContainsKey('Model')) { $Model='deepseek/deepseek-v4-flash:free' } }
    '2' { $Provider='anthropic'; if (-not $PSBoundParameters.ContainsKey('Model')) { $Model='claude-sonnet-4' } }
    '3' { $Provider='openai'; if (-not $PSBoundParameters.ContainsKey('Model')) { $Model='gpt-4.1' } }
    '4' { $Provider='google'; if (-not $PSBoundParameters.ContainsKey('Model')) { $Model='gemini-2.0-flash' } }
    '5' { $Provider='deepseek'; if (-not $PSBoundParameters.ContainsKey('Model')) { $Model='deepseek-chat' } }
    '6' { $Provider='custom' }
    default { Die "Invalid provider choice: $choice" }
  }
  $modelInput = Read-Host "Model [$Model]"
  if ($modelInput) { $Model = $modelInput }
}

Resolve-Port

if (-not $ApiServerKey) { $ApiServerKey = New-SecretHex }

$selectedKey = switch ($Provider) {
  'openrouter' { $OpenRouterApiKey }
  'anthropic' { $AnthropicApiKey }
  'openai' { $OpenAIApiKey }
  'google' { $GoogleApiKey }
  'deepseek' { $DeepSeekApiKey }
  'custom' { $CustomApiKey }
}
if (-not $selectedKey) {
  $selectedKey = Read-Host "API key for provider '$Provider' (press Enter to skip)"
}
if (-not $selectedKey) {
  Warn "No API key provided. Hermes will install, but model calls will fail until you edit $InstallDir\.env."
} elseif ($selectedKey.Length -lt 12) {
  Warn "API key looks unusually short. Continuing, but verify it in $InstallDir\.env if model calls fail."
}

$orKey=''; $anthKey=''; $oaKey=''; $gKey=''; $gemKey=''; $dsKey=''; $cKey=''
switch ($Provider) {
  'openrouter' { $orKey=$selectedKey }
  'anthropic' { $anthKey=$selectedKey }
  'openai' { $oaKey=$selectedKey }
  'google' { $gKey=$selectedKey; $gemKey=$selectedKey }
  'deepseek' { $dsKey=$selectedKey }
  'custom' { $cKey=$selectedKey }
}

$installBrowser = if ($Browser) { '1' } else { '0' }

# ── Generate files ──────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'workspace') | Out-Null
Set-Location $InstallDir

Safe-Write '.env' @"
COMPOSE_PROJECT_NAME=$ProjectName
MODEL_PROVIDER=$Provider
MODEL_NAME=$Model
API_SERVER_PORT=$Port
API_SERVER_KEY=$ApiServerKey
INSTALL_BROWSER=$installBrowser
HERMES_VERSION=$HermesVersion
# Provider keys. Fill only the provider you use.
$(if ($orKey) { "OPENROUTER_API_KEY=$orKey" })
$(if ($anthKey) { "ANTHROPIC_API_KEY=$anthKey" })
$(if ($oaKey) { "OPENAI_API_KEY=$oaKey" })
$(if ($gKey) { "GOOGLE_API_KEY=$gKey" })
$(if ($gemKey) { "GEMINI_API_KEY=$gemKey" })
$(if ($dsKey) { "DEEPSEEK_API_KEY=$dsKey" })
$(if ($cKey) { "CUSTOM_API_KEY=$cKey" })
$(if ($CustomBaseUrl) { "CUSTOM_BASE_URL=$CustomBaseUrl" })
"@

Safe-Write 'Dockerfile' @'
# Stage 1: Builder — install Hermes + Python deps
FROM python:3.12-slim-bookworm AS builder
ARG INSTALL_BROWSER=1
ARG HERMES_VERSION=main
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential python3-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch $HERMES_VERSION \
    https://github.com/NousResearch/hermes-agent.git /src/hermes && \
    python3 -m venv /venv && \
    /venv/bin/pip install --no-cache-dir -U pip setuptools wheel && \
    /venv/bin/pip install --no-cache-dir '/src/hermes[all]' && \
    rm -rf /src/hermes /root/.cache /tmp/*

# Stage 2: Runtime
FROM python:3.12-slim-bookworm
ARG INSTALL_BROWSER=1
ENV DEBIAN_FRONTEND=noninteractive \
    HERMES_HOME=/root/.hermes \
    PATH=/venv/bin:/root/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl tmux cron jq ripgrep fd-find \
    procps less nano openssh-client netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /venv /venv

RUN if [ "$INSTALL_BROWSER" = "1" ]; then \
      /venv/bin/pip install --no-cache-dir playwright && \
      /venv/bin/python -m playwright install --with-deps chromium; \
    fi

COPY bootstrap.sh /usr/local/bin/bootstrap.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/bootstrap.sh /usr/local/bin/healthcheck.sh

WORKDIR /workspace
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD /usr/local/bin/healthcheck.sh
ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
CMD ["hermes", "gateway", "run"]
'@

Safe-Write 'bootstrap.sh' @'
#!/usr/bin/env bash
set -Eeuo pipefail
export HERMES_HOME="${HERMES_HOME:-/root/.hermes}"
export PATH="/venv/bin:/root/.local/bin:$PATH"
mkdir -p "$HERMES_HOME" /workspace "$HERMES_HOME/logs"

MODEL_PROVIDER="${MODEL_PROVIDER:-openrouter}"
MODEL_NAME="${MODEL_NAME:-deepseek/deepseek-v4-flash:free}"
API_SERVER_KEY="${API_SERVER_KEY:-change-me}"
API_SERVER_PORT="${API_SERVER_PORT:-8642}"
CUSTOM_BASE_URL="${CUSTOM_BASE_URL:-}"

cat > "$HERMES_HOME/.env" <<EOENV
API_SERVER_KEY=$API_SERVER_KEY
GATEWAY_ALLOW_ALL_USERS=true
PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
EOENV

# Write only the relevant provider key
case "$MODEL_PROVIDER" in
  openrouter) echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" >> "$HERMES_HOME/.env" ;;
  anthropic)  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" >> "$HERMES_HOME/.env" ;;
  openai)     echo "OPENAI_API_KEY=${OPENAI_API_KEY:-}" >> "$HERMES_HOME/.env" ;;
  google)
    echo "GOOGLE_API_KEY=${GOOGLE_API_KEY:-}" >> "$HERMES_HOME/.env"
    echo "GEMINI_API_KEY=${GEMINI_API_KEY:-}" >> "$HERMES_HOME/.env" ;;
  deepseek)   echo "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}" >> "$HERMES_HOME/.env" ;;
  custom)
    echo "CUSTOM_API_KEY=${CUSTOM_API_KEY:-}" >> "$HERMES_HOME/.env"
    echo "CUSTOM_BASE_URL=${CUSTOM_BASE_URL:-}" >> "$HERMES_HOME/.env" ;;
esac

chmod 600 "$HERMES_HOME/.env" || true

cat > "$HERMES_HOME/config.yaml" <<EOCFG
model:
  provider: "$MODEL_PROVIDER"
  default: "$MODEL_NAME"
  base_url: "$CUSTOM_BASE_URL"

terminal:
  backend: local
  cwd: /workspace
  timeout: 180

memory:
  memory_enabled: true
  user_profile_enabled: true

approvals:
  mode: manual

platforms:
  api_server:
    enabled: true
    extra:
      host: "0.0.0.0"
      port: $API_SERVER_PORT
      key: "$API_SERVER_KEY"
EOCFG

for tool in terminal file web browser vision skills memory session_search delegation cronjob todo; do
  hermes tools enable "$tool" >/dev/null 2>&1 || true
done

exec "$@"
'@

Safe-Write 'healthcheck.sh' @'
#!/usr/bin/env bash
# Hermes Docker Healthcheck
set -euo pipefail
PORT="${API_SERVER_PORT:-8642}"
if command -v curl >/dev/null 2>&1; then
  curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1
elif command -v nc >/dev/null 2>&1; then
  nc -z 127.0.0.1 "$PORT" >/dev/null 2>&1
else
  exec 3<>/dev/tcp/127.0.0.1/"$PORT" 2>/dev/null
fi
'@

Safe-Write 'docker-compose.yml' @'
services:
  hermes:
    build:
      context: .
      args:
        INSTALL_BROWSER: ${INSTALL_BROWSER:-0}
        HERMES_VERSION: ${HERMES_VERSION:-main}
    image: local/hermes-agent:latest
    container_name: hermes-agent
    env_file:
      - .env
    ports:
      - "${API_SERVER_PORT:-8642}:${API_SERVER_PORT:-8642}"
    volumes:
      - hermes_home:/root/.hermes
      - ./workspace:/workspace
    stdin_open: true
    tty: true
    restart: unless-stopped
    command: ["hermes", "gateway", "run"]

volumes:
  hermes_home:
'@

Safe-Write 'hermes-docker.ps1' @'
param([string]$Command='help')
$ErrorActionPreference='Stop'
Set-Location $PSScriptRoot
switch ($Command) {
  'start' { docker compose up -d }
  'stop' { docker compose stop }
  'restart' { docker compose restart }
  'status' { docker compose ps }
  'logs' { docker compose logs -f hermes }
  'cli' { docker compose exec hermes hermes }
  'shell' { docker compose exec hermes bash }
  'build' { docker compose build }
  'update' { docker compose build --pull; docker compose up -d }
  'down' { docker compose down }
  'reset' { docker compose down -v }
  'url' { $envfile=Get-Content .env; ($envfile | Where-Object {$_ -like 'API_SERVER_PORT=*'}) -replace 'API_SERVER_PORT=','' | ForEach-Object { "http://localhost:$_" } }
  'key' { (Get-Content .env | Where-Object {$_ -like 'API_SERVER_KEY=*'}) -replace 'API_SERVER_KEY=','' }
  default { Write-Host 'Commands: start stop restart status logs cli shell build update down reset url key' }
}
'@

Safe-Write 'README.md' @"
# Hermes Agent Docker

Commands:

    .\hermes-docker.ps1 start
    .\hermes-docker.ps1 cli
    .\hermes-docker.ps1 logs
    .\hermes-docker.ps1 status
    .\hermes-docker.ps1 update

API server:

    http://localhost:$Port

Edit config/API keys:

    $InstallDir\.env
"@

# ── Build and start ─────────────────────────────────────────────

if ($SkipBuild) {
  Log 'Generated files only; skipping Docker build/start.'
  if ($CanValidateCompose) {
    docker compose config | Out-Null
    Ok 'Docker Compose config is valid'
  } else {
    Warn 'Skipped Docker Compose validation because Docker is not available.'
  }
} else {
  if ($Browser) {
    Log 'Building Docker image with Playwright/Chromium (may take 5-10 minutes)...'
  } else {
    Log 'Building Docker image. Add -Browser for Playwright/Chromium (~450 MB extra, default: skip).'
  }
  docker compose build
  if (-not $NoStart) {
    docker compose up -d
    docker compose ps
    Wait-Health
  }
}

Ok 'Hermes Agent Docker is installed.'
Write-Host "Install directory: $InstallDir"
Write-Host "Open CLI: cd '$InstallDir'; .\hermes-docker.ps1 cli"
Write-Host "Logs: cd '$InstallDir'; .\hermes-docker.ps1 logs"
Write-Host "API server: http://localhost:$Port"
