# Hades Installer for Windows PowerShell
# Requires Docker Desktop with WSL2 backend enabled.
# Usage:
#   .\install.ps1
#   .\install.ps1 -Provider openrouter -Model deepseek/deepseek-v4-flash:free -OpenRouterApiKey sk-...

param(
  [string]$Version = '1.4.2',
  [string]$InstallDir = $(
    $isAdmin = [bool](([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    if ($isAdmin) { Join-Path $env:ProgramFiles 'hades' } else { "$env:USERPROFILE\.hades" }
  ),
  [ValidateSet('openrouter','anthropic','openai','google','deepseek','custom')]
  [string]$Provider = 'openrouter',
  [string]$Model = 'deepseek/deepseek-v4-flash:free',
  [int]$Port = 8642,
  [string]$ProjectName = 'hades',
  [switch]$NoStart,
  [switch]$Browser,
  [switch]$SkipBuild,
  [switch]$Force,
  [switch]$Uninstall,
  [string]$GpuDevices = '',
  [string]$HermesVersion = $(if ($env:HERMES_VERSION) { $env:HERMES_VERSION } else { 'v2026.5.29.2' }),
  [string]$OpenRouterApiKey = $env:OPENROUTER_API_KEY,
  [string]$AnthropicApiKey = $env:ANTHROPIC_API_KEY,
  [string]$OpenAIApiKey = $env:OPENAI_API_KEY,
  [string]$GoogleApiKey = $(if ($env:GOOGLE_API_KEY) { $env:GOOGLE_API_KEY } else { $env:GEMINI_API_KEY }),
  [string]$DeepSeekApiKey = $env:DEEPSEEK_API_KEY,
  [string]$CustomApiKey = $env:CUSTOM_API_KEY,
  [string]$CustomBaseUrl = $env:CUSTOM_BASE_URL,
  [string]$ApiServerKey = $env:API_SERVER_KEY,
  [string]$ApprovalMode = $(if ($env:APPROVAL_MODE) { $env:APPROVAL_MODE } else { 'manual' })
)

# Guard against environment leakage
if ($env:PYTHONPATH) { Remove-Item env:PYTHONPATH -ErrorAction SilentlyContinue }
if ($env:PYTHONHOME) { Remove-Item env:PYTHONHOME -ErrorAction SilentlyContinue }

$isAdmin = [bool](([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
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
  if ((Test-Path $Path) -and $Force) {
    Copy-Item $Path "$Path.bak" -Force
    Log "Backed up $Path to $Path.bak"
  }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Test-PortInUse([int]$Port) {
  try {
    $conn = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop
    return [bool]$conn
  } catch { return $false }
}

function Resolve-Port() {
  if ($Port -lt 1 -or $Port -gt 65535) {
    Die "Invalid port: $Port. Must be between 1 and 65535."
  }
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

# ── Uninstall ───────────────────────────────────────────────────

Log 'Hades Installer for Windows'

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
    docker compose version *> $null
    if ($LASTEXITCODE -eq 0) {
      Push-Location $InstallDir
      docker compose down --remove-orphans *> $null
      Log "Stack stopped. Files kept at: $InstallDir"
      $ans = Read-Host 'Remove data volume too? (y/N)'
      if ($ans -match '^(y|yes)$') { docker compose down -v --remove-orphans; Ok 'Removed stack and data volume' }
      else { Ok 'Removed stack, kept data volume' }
      Pop-Location
    } else {
      Warn 'Docker Compose v2 is not available. Skipping stack shutdown.'
      Warn "Files kept at: $InstallDir"
    }
  } else {
    Warn "Files kept at: $InstallDir"
  }
  exit 0
}

# ── Preflight ──────────────────────────────────────────────────

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
    '6' { $Provider='custom'; if (-not $PSBoundParameters.ContainsKey('Model')) { $Model='custom-model' } }
    default { Die "Invalid provider choice: $choice" }
  }

  # Prompt API key immediately after choosing provider
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
  # Save to the respective API key variable
  switch ($Provider) {
    'openrouter' { $OpenRouterApiKey = $selectedKey }
    'anthropic' { $AnthropicApiKey = $selectedKey }
    'openai' { $OpenAIApiKey = $selectedKey }
    'google' { $GoogleApiKey = $selectedKey }
    'deepseek' { $DeepSeekApiKey = $selectedKey }
    'custom' { $CustomApiKey = $selectedKey }
  }

  $modelInput = Read-Host "Model [$Model]"
  if ($modelInput) { $Model = $modelInput }
} else {
  # If Provider was specified as a CLI arg, check if key is provided or prompt
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
  switch ($Provider) {
    'openrouter' { $OpenRouterApiKey = $selectedKey }
    'anthropic' { $AnthropicApiKey = $selectedKey }
    'openai' { $OpenAIApiKey = $selectedKey }
    'google' { $GoogleApiKey = $selectedKey }
    'deepseek' { $DeepSeekApiKey = $selectedKey }
    'custom' { $CustomApiKey = $selectedKey }
  }
}

if (-not $NoStart -and -not $SkipBuild) {
  Resolve-Port
}

if (-not $ApiServerKey) { $ApiServerKey = New-SecretHex }

if (-not $selectedKey) {
  Warn "No API key provided. Hermes will install, but model calls will fail until you edit $InstallDir\.env."
} elseif ($selectedKey.Length -lt 12) {
  Warn "API key looks unusually short. Continuing, but verify it in $InstallDir\.env if model calls fail."
}

$installBrowser = if ($Browser) { '1' } else { '0' }

# ── Generate files ──────────────────────────────────────────────

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'workspace') | Out-Null
Set-Location $InstallDir

# Register Path environment variable
$binPath = Join-Path $InstallDir 'bin'
New-Item -ItemType Directory -Force -Path $binPath | Out-Null

$targetEnvScope = if ($isAdmin) { 'Machine' } else { 'User' }
$currentPaths = [System.Environment]::GetEnvironmentVariable('Path', $targetEnvScope)
if ($currentPaths -notlike "*$binPath*") {
  $separator = if ($currentPaths.EndsWith(';') -or $currentPaths -eq '') { '' } else { ';' }
  [System.Environment]::SetEnvironmentVariable('Path', "$currentPaths$separator$binPath", $targetEnvScope)
  # Update local process Path
  $env:Path = "$env:Path;$binPath"
  Ok "Added $binPath to $targetEnvScope Path environment variable"
}

if ($Force) {
  if (Test-Path '.env') {
    Log 'Backing up existing .env to .env.bak'
    Copy-Item '.env' '.env.bak' -Force
  }
}

# Write .env with only the active provider's key (matching install.sh behavior)
switch ($Provider) {
  'google' {
    Safe-Write '.env' @"
COMPOSE_PROJECT_NAME=$ProjectName
MODEL_PROVIDER=$Provider
MODEL_NAME=$Model
API_SERVER_PORT=$Port
API_SERVER_KEY=$ApiServerKey
INSTALL_BROWSER=$installBrowser
HERMES_VERSION=$HermesVersion
APPROVAL_MODE=$ApprovalMode
GPU_DEVICES=$GpuDevices
GOOGLE_API_KEY=$GoogleApiKey
GEMINI_API_KEY=$GoogleApiKey
"@
  }
  'custom' {
    Safe-Write '.env' @"
COMPOSE_PROJECT_NAME=$ProjectName
MODEL_PROVIDER=$Provider
MODEL_NAME=$Model
API_SERVER_PORT=$Port
API_SERVER_KEY=$ApiServerKey
INSTALL_BROWSER=$installBrowser
HERMES_VERSION=$HermesVersion
APPROVAL_MODE=$ApprovalMode
GPU_DEVICES=$GpuDevices
CUSTOM_API_KEY=$CustomApiKey
$(if ($CustomBaseUrl) { "CUSTOM_BASE_URL=$CustomBaseUrl" })
"@
  }
  default {
    $keyVar = switch ($Provider) {
      'openrouter' { 'OPENROUTER_API_KEY' }
      'anthropic' { 'ANTHROPIC_API_KEY' }
      'openai' { 'OPENAI_API_KEY' }
      'deepseek' { 'DEEPSEEK_API_KEY' }
    }
    $keyValue = switch ($Provider) {
      'openrouter' { $OpenRouterApiKey }
      'anthropic' { $AnthropicApiKey }
      'openai' { $OpenAIApiKey }
      'deepseek' { $DeepSeekApiKey }
    }
    Safe-Write '.env' @"
COMPOSE_PROJECT_NAME=$ProjectName
MODEL_PROVIDER=$Provider
MODEL_NAME=$Model
API_SERVER_PORT=$Port
API_SERVER_KEY=$ApiServerKey
INSTALL_BROWSER=$installBrowser
HERMES_VERSION=$HermesVersion
APPROVAL_MODE=$ApprovalMode
GPU_DEVICES=$GpuDevices
${keyVar}=${keyValue}
"@
  }
}

Safe-Write 'Dockerfile' @'
# Stage 1: Builder — install Hermes + Python deps
FROM python:3.12-slim-bookworm AS builder
ARG INSTALL_BROWSER=0
ARG HERMES_VERSION=v2026.5.29.2
RUN apt-get update && apt-get install -y --no-install-recommends \
    git ca-certificates build-essential python3-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch $HERMES_VERSION \
    https://github.com/NousResearch/hermes-agent.git /src/hermes && \
    python3 -m venv /venv && \
    /venv/bin/pip install --no-cache-dir -U pip setuptools wheel && \
    /venv/bin/pip install --no-cache-dir '/src/hermes[gateway,tools]' && \
    rm -rf /src/hermes /root/.cache /tmp/*

# Stage 2: Runtime
FROM python:3.12-slim-bookworm
ARG INSTALL_BROWSER=0
ENV DEBIAN_FRONTEND=noninteractive \
    HADES_HOME=/home/hermes/.hermes \
    PATH=/venv/bin:/home/hermes/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates curl tmux cron jq ripgrep fd-find \
    procps less nano openssh-client netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -u 1000 -s /bin/bash hermes

COPY --from=builder /venv /venv

RUN if [ "$INSTALL_BROWSER" = "1" ]; then \
      /venv/bin/pip install --no-cache-dir playwright && \
      /venv/bin/python -m playwright install --with-deps chromium; \
    fi

COPY bootstrap.sh /usr/local/bin/bootstrap.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod +x /usr/local/bin/bootstrap.sh /usr/local/bin/healthcheck.sh

RUN mkdir -p /home/hermes/.local/bin /home/hermes/.cache && \
    chown -R hermes:hermes /venv /home/hermes

WORKDIR /workspace
USER hermes
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD /usr/local/bin/healthcheck.sh
ENTRYPOINT ["/usr/local/bin/bootstrap.sh"]
CMD ["hermes", "gateway", "run"]
'@

Safe-Write 'bootstrap.sh' @'
#!/usr/bin/env bash
set -Eeuo pipefail
export HADES_HOME="${HADES_HOME:-/home/hermes/.hermes}"
export HOME="/home/hermes"
export PATH="/venv/bin:/home/hermes/.local/bin:$PATH"
mkdir -p "$HADES_HOME" /workspace "$HADES_HOME/logs"

# Migration: if old /root/.hermes exists with data, move it to new home
if [[ -d /root/.hermes ]] && [[ ! -f "$HADES_HOME/.hermes_initialized" ]]; then
  mkdir -p "$(dirname "$HADES_HOME")"
  if [[ -d /root/.hermes/sessions ]] || [[ -d /root/.hermes/memories ]] || [[ -d /root/.hermes/skills ]]; then
    echo "HADES: migrating /root/.hermes to $HADES_HOME..."
    cp -a /root/.hermes/. "$HADES_HOME/" 2>/dev/null || true
    echo "HADES: migration complete"
  fi
  rm -rf /root/.hermes
  touch "$HADES_HOME/.hermes_initialized"
fi

MODEL_PROVIDER="${MODEL_PROVIDER:-openrouter}"
MODEL_NAME="${MODEL_NAME:-deepseek/deepseek-v4-flash:free}"
if [[ -z "${API_SERVER_KEY:-}" ]]; then
  echo "ERROR: API_SERVER_KEY is not set. Aborting." >&2
  exit 1
fi
API_SERVER_PORT="${API_SERVER_PORT:-8642}"
CUSTOM_BASE_URL="${CUSTOM_BASE_URL:-}"
APPROVAL_MODE="${APPROVAL_MODE:-manual}"

# Always regenerate .env from current env vars (with hash guard)
GENERATED_ENV=$(cat <<EOENV
API_SERVER_KEY=$API_SERVER_KEY
GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS:-true}
PLAYWRIGHT_BROWSERS_PATH=/home/hermes/.cache/ms-playwright
APPROVAL_MODE=$APPROVAL_MODE
EOENV
)

# Write only the relevant provider key(s)
case "$MODEL_PROVIDER" in
  openrouter) GENERATED_ENV="$GENERATED_ENV"$'\n'"OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" ;;
  anthropic)  GENERATED_ENV="$GENERATED_ENV"$'\n'"ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" ;;
  openai)     GENERATED_ENV="$GENERATED_ENV"$'\n'"OPENAI_API_KEY=${OPENAI_API_KEY:-}" ;;
  google)
    GENERATED_ENV="$GENERATED_ENV"$'\n'"GOOGLE_API_KEY=${GOOGLE_API_KEY:-}"
    GENERATED_ENV="$GENERATED_ENV"$'\n'"GEMINI_API_KEY=${GEMINI_API_KEY:-}" ;;
  deepseek)   GENERATED_ENV="$GENERATED_ENV"$'\n'"DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}" ;;
  custom)
    GENERATED_ENV="$GENERATED_ENV"$'\n'"CUSTOM_API_KEY=${CUSTOM_API_KEY:-}"
    GENERATED_ENV="$GENERATED_ENV"$'\n'"CUSTOM_BASE_URL=${CUSTOM_BASE_URL:-}" ;;
esac

CURRENT_ENV_HASH=$(echo "$GENERATED_ENV" | md5sum 2>/dev/null | cut -d' ' -f1)
EXISTING_ENV_HASH=""
if [[ -f "$HADES_HOME/.env" ]]; then
  EXISTING_ENV_HASH=$(md5sum "$HADES_HOME/.env" 2>/dev/null | cut -d' ' -f1)
fi

if [[ "$CURRENT_ENV_HASH" != "$EXISTING_ENV_HASH" ]]; then
  echo "$GENERATED_ENV" > "$HADES_HOME/.env"
  chmod 600 "$HADES_HOME/.env" || true
fi

# Always regenerate config.yaml from current env vars (with hash guard)
GENERATED_CFG=$(cat <<EOCFG
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
  mode: $APPROVAL_MODE

platforms:
  api_server:
    enabled: true
    extra:
      host: "0.0.0.0"
      port: $API_SERVER_PORT
      key: "$API_SERVER_KEY"
EOCFG
)

CURRENT_CFG_HASH=$(echo "$GENERATED_CFG" | md5sum 2>/dev/null | cut -d' ' -f1)
EXISTING_CFG_HASH=""
if [[ -f "$HADES_HOME/config.yaml" ]]; then
  EXISTING_CFG_HASH=$(md5sum "$HADES_HOME/config.yaml" 2>/dev/null | cut -d' ' -f1)
fi

if [[ "$CURRENT_CFG_HASH" != "$EXISTING_CFG_HASH" ]]; then
  echo "$GENERATED_CFG" > "$HADES_HOME/config.yaml"
  for tool in terminal file web browser vision skills memory session_search delegation cronjob todo; do
    hermes tools enable "$tool" >/dev/null 2>&1 || true
  done
fi

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
  echo "ERROR: neither curl nor nc found. Cannot health-check." >&2
  exit 1
fi
'@

Safe-Write 'docker-compose.yml' @'
services:
  hermes:
    build:
      context: .
      args:
        INSTALL_BROWSER: ${INSTALL_BROWSER:-0}
        HERMES_VERSION: ${HERMES_VERSION:-v2026.5.29.2}
        PYTHON_VERSION: ${PYTHON_VERSION:-3.12-slim-bookworm}
    image: local/hermes-agent:latest
    env_file:
      - .env
    environment:
      GATEWAY_ALLOW_ALL_USERS: ${GATEWAY_ALLOW_ALL_USERS:-true}
      APPROVAL_MODE: ${APPROVAL_MODE:-manual}
    ports:
      - "127.0.0.1:${API_SERVER_PORT:-8642}:${API_SERVER_PORT:-8642}"
    volumes:
      - hermes_home:/home/hermes/.hermes
      - ./workspace:/workspace
    stdin_open: true
    tty: true
    restart: unless-stopped
    command: ["hermes", "gateway", "run"]

volumes:
  hermes_home:
'@
    if ($GpuDevices) {
      $composeFile = Join-Path $InstallDir 'docker-compose.yml'
      $content = Get-Content $composeFile -Raw
      $gpuBlock = if ($GpuDevices -eq 'all') {
@'
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
'@
      } else {
@"
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              device_ids: ["$GpuDevices"]
              capabilities: [gpu]
"@
      }
      $content = $content -replace '(?m)^    command: \[', "$gpuBlock`$&"
      Set-Content -Path $composeFile -Value $content -Encoding UTF8 -NoNewline
    }

Safe-Write 'bin/hades.ps1' @'
param([string]$Command='help')
$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
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
  'backup' {
    $ts = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dest = Join-Path (Get-Location) 'backups'
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $finalFile = Join-Path $dest "hermes-data-$ts.tar.gz"
    # Create tar inside container (absolute path to match bash format)
    docker compose exec -T hermes tar czf /tmp/hades-backup.tar.gz /home/hermes/.hermes 2>$null
    if ($LASTEXITCODE -eq 0) {
      $cid = docker compose ps -q hermes 2>$null
      if ($cid) {
        docker cp "${cid}:/tmp/hades-backup.tar.gz" $finalFile 2>$null
        docker compose exec hermes rm -f /tmp/hades-backup.tar.gz 2>$null
        if ((Test-Path $finalFile) -and ((Get-Item $finalFile).Length -gt 0)) {
          Write-Host "OK: Backup saved to $finalFile" -ForegroundColor Green
          return
        }
      }
    }
    # Fallback: backup host config only
    Copy-Item .env "$dest/env-$ts.bak" -Force
    Copy-Item docker-compose.yml "$dest/docker-compose-$ts.yml" -Force
    Write-Host "WARN: Cannot reach container; backed up host config only." -ForegroundColor Yellow
  }
  'restore' {
    $src = $args[0]
    if (-not $src) { Write-Host "Usage: hades restore <backup-file>"; return }
    if (-not (Test-Path $src)) { Write-Host "ERROR: Backup not found: $src" -ForegroundColor Red; return }
    $state = docker compose ps --format '{{.State}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or $state -ne 'running') { Write-Host "ERROR: Container is not running. Start it with 'hades start' first." -ForegroundColor Red; return }
    $cid = docker compose ps -q hermes 2>$null
    if (-not $cid) { Write-Host "ERROR: Cannot determine container ID." -ForegroundColor Red; return }
    $tmpDir = Join-Path $env:TEMP "hades-restore-$([IO.Path]::GetRandomFileName())"
    New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
    tar xzf $src -C $tmpDir
    # Stage tar into container via docker cp (handles binary correctly)
    docker compose exec -T hermes mkdir -p /tmp/hades-restore 2>$null
    if (Test-Path "$tmpDir/root/.hermes") {
      # Old-format backup: /root/.hermes/...
      docker cp $src "${cid}:/tmp/hades-restore/backup.tar.gz"
      if ($LASTEXITCODE -ne 0) { Remove-Item -Recurse -Force $tmpDir; Write-Host "ERROR: Failed to copy backup to container." -ForegroundColor Red; return }
      docker compose exec -T hermes bash -c "mkdir -p /home/hermes/.hermes && tar xzf /tmp/hades-restore/backup.tar.gz -C /home/hermes/.hermes --strip-components=2 && rm -rf /tmp/hades-restore"
      if ($LASTEXITCODE -ne 0) { Remove-Item -Recurse -Force $tmpDir; Write-Host "ERROR: Failed to extract backup inside container." -ForegroundColor Red; return }
    } else {
      # New-format backup: tar at root
      docker cp $src "${cid}:/tmp/hades-restore/backup.tar.gz"
      if ($LASTEXITCODE -ne 0) { Remove-Item -Recurse -Force $tmpDir; Write-Host "ERROR: Failed to copy backup to container." -ForegroundColor Red; return }
      docker compose exec -T hermes bash -c "tar xzf /tmp/hades-restore/backup.tar.gz -C / && rm -rf /tmp/hades-restore"
      if ($LASTEXITCODE -ne 0) { Remove-Item -Recurse -Force $tmpDir; Write-Host "ERROR: Failed to extract backup inside container." -ForegroundColor Red; return }
    }
    Remove-Item -Recurse -Force $tmpDir
    Write-Host "OK: Restored from $src" -ForegroundColor Green
    docker compose restart hermes
  }
  'check' {
    $exitCode = 0
    $state = docker compose ps --format '{{.State}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or $state -ne 'running') { Write-Host "FAIL: container not running" -ForegroundColor Red; $exitCode = 1 }
    $envContent = Get-Content .env -ErrorAction SilentlyContinue
    $port = ($envContent | Where-Object {$_ -like 'API_SERVER_PORT=*'}) -replace 'API_SERVER_PORT=',''
    if (-not $port) { $port = '8642' }
    try {
      Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 5 | Out-Null
      Write-Host "OK: healthcheck endpoint reachable" -ForegroundColor Green
    } catch {
      Write-Host "FAIL: healthcheck endpoint unreachable" -ForegroundColor Red; $exitCode = 1
    }
    if ($exitCode -eq 0) { Write-Host "OK: All checks passed" -ForegroundColor Green } else { docker compose logs --tail 20 hermes }
  }
  'url' { $envfile=Get-Content .env; ($envfile | Where-Object {$_ -like 'API_SERVER_PORT=*'}) -replace 'API_SERVER_PORT=','' | ForEach-Object { "http://localhost:$_" } }
  'key' { (Get-Content .env | Where-Object {$_ -like 'API_SERVER_KEY=*'}) -replace 'API_SERVER_KEY=','' }
  default { Write-Host 'Commands: start stop restart status logs cli shell build update down reset backup restore check url key' }
}
'@

Safe-Write 'bin/hades.cmd' @"
@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0hades.ps1" %*
"@

Safe-Write 'README.md' @"
# Hades

Commands:

    hades start
    hades cli
    hades logs
    hades status
    hades update

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
  Log "Attempting to pull prebuilt image — will try multiple tags..."
  $pulled = $false
  foreach ($pullTag in @("v$Version", "hermes-$HermesVersion", "latest")) {
    $pullResult = docker pull "ghcr.io/lunaticbugbear/hades-hermes-agent:$pullTag" 2>&1
    if ($LASTEXITCODE -eq 0) {
      Ok "Prebuilt image pull succeeded (tag: $pullTag) — skipping local build."
      docker tag "ghcr.io/lunaticbugbear/hades-hermes-agent:$pullTag" "local/hermes-agent:latest"
      $pulled = $true
      break
    }
  }
  if (-not $pulled) {
    Log 'No prebuilt image available. Building locally...'
    docker compose build
  }
  if (-not $NoStart) {
    docker compose up -d
    docker compose ps
    Wait-Health
  }
}

Ok 'Hades is installed.'
Write-Host "Install directory: $InstallDir"
Write-Host "Open CLI: hades cli"
Write-Host "Logs: hades logs"
Write-Host "API server: http://localhost:$Port"
