#!/usr/bin/env bash
# Hades Installer
# Cross-platform installer for Linux, macOS, and Windows via WSL/Git Bash.
# Windows native users should use install.ps1 or run this in WSL.
#
# Quick install:
#   bash install.sh
#
# Non-interactive:
#   HERMES_NONINTERACTIVE=1 OPENROUTER_API_KEY=... bash install.sh
#
# Options:
#   --dir PATH              Install directory, default: ~/.hades
#   --provider PROVIDER     openrouter|anthropic|openai|google|deepseek|custom, default: openrouter
#   --model MODEL           Model name, default: deepseek/deepseek-v4-flash:free
#   --port PORT             Host/API port, default: 8642
#   --name NAME             Docker Compose project/container prefix, default: hades
#   --no-start              Build but do not start
#   --browser               Include Playwright + Chromium (~450 MB, +5 min build)
#   --skip-build            Generate files only; do not build/start, useful for CI
#   --force                 Overwrite generated Dockerfile/bootstrap/compose/helper files
#   --uninstall             Stop stack and optionally remove data volume
#   --help                  Show help

set -Eeuo pipefail
IFS=$' \n\t'

# Guard against environment leakage
if [ -n "${PYTHONPATH:-}" ]; then
  unset PYTHONPATH
fi
if [ -n "${PYTHONHOME:-}" ]; then
  unset PYTHONHOME
fi

VERSION="1.3.0"
DEFAULT_DIR=""
if [ "$(id -u)" -eq 0 ]; then
  DEFAULT_DIR="/usr/local/lib/hades"
else
  DEFAULT_DIR="$HOME/.hades"
fi
INSTALL_DIR="$DEFAULT_DIR"
PROJECT_NAME="hades"
PROVIDER="openrouter"
MODEL="deepseek/deepseek-v4-flash:free"
API_PORT="8642"
START_AFTER_INSTALL="1"
INSTALL_BROWSER="0"
SKIP_BUILD="0"
FORCE="0"
UNINSTALL="0"
HERMES_VERSION="${HERMES_VERSION:-v2026.5.29.2}"
NONINTERACTIVE="${HERMES_NONINTERACTIVE:-0}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
if [[ ! -t 1 ]]; then RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''; fi

log() { printf "%b\n" "${BLUE}==>${NC} $*"; }
ok() { printf "%b\n" "${GREEN}OK:${NC} $*"; }
warn() { printf "%b\n" "${YELLOW}WARN:${NC} $*"; }
err() { printf "%b\n" "${RED}ERROR:${NC} $*" >&2; }
die() { err "$*"; exit 1; }

usage() { sed -n '1,35p' "$0"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --provider) PROVIDER="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --port) API_PORT="$2"; shift 2 ;;
    --name) PROJECT_NAME="$2"; shift 2 ;;
    --no-start) START_AFTER_INSTALL="0"; shift ;;
    --browser) INSTALL_BROWSER="1"; shift ;;
    --skip-build) SKIP_BUILD="1"; START_AFTER_INSTALL="0"; shift ;;
    --force) FORCE="1"; shift ;;
    --uninstall) UNINSTALL="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

if [[ "$NONINTERACTIVE" != "1" ]]; then
  # Probe by opening /dev/tty
  if (: </dev/tty) 2>/dev/null; then
    exec < /dev/tty
    echo
    echo "Hades Installer"
    echo "Choose your model provider:"
    echo "  1) OpenRouter  recommended, many models"
    echo "  2) Anthropic"
    echo "  3) OpenAI"
    echo "  4) Google Gemini"
    echo "  5) DeepSeek"
    echo "  6) Custom OpenAI-compatible endpoint"
    printf "Provider [1]: "
    read -r provider_choice || true
    case "${provider_choice:-1}" in
      1) PROVIDER="openrouter"; MODEL="${MODEL:-deepseek/deepseek-v4-flash:free}" ;;
      2) PROVIDER="anthropic"; MODEL="claude-sonnet-4" ;;
      3) PROVIDER="openai"; MODEL="gpt-4.1" ;;
      4) PROVIDER="google"; MODEL="gemini-2.0-flash" ;;
      5) PROVIDER="deepseek"; MODEL="deepseek-chat" ;;
      6) PROVIDER="custom"; MODEL="${MODEL:-model-name}" ;;
      *) die "Invalid provider choice: $provider_choice" ;;
    esac

    # Prompt API key immediately after choosing provider
    key_var=""
    case "$PROVIDER" in
      openrouter) key_var="OPENROUTER_API_KEY" ;;
      anthropic) key_var="ANTHROPIC_API_KEY" ;;
      openai) key_var="OPENAI_API_KEY" ;;
      google) key_var="GOOGLE_API_KEY" ;;
      deepseek) key_var="DEEPSEEK_API_KEY" ;;
      custom) key_var="CUSTOM_API_KEY" ;;
    esac

    # shellcheck disable=SC2015
    env_val="${!key_var:-}"
    if [[ -z "$env_val" ]]; then
      printf "API key for provider '%s' (press Enter to skip): " "$PROVIDER"
      read -r -s api_key_input || true
      printf "\n"
      # shellcheck disable=SC2034
      printf -v "$key_var" '%s' "$api_key_input"
    fi

    printf "Model [%s]: " "$MODEL"
    read -r model_choice || true
    MODEL="${model_choice:-$MODEL}"
    printf "API server port [%s]: " "$API_PORT"
    read -r port_choice || true
    API_PORT="${port_choice:-$API_PORT}"
  fi
fi

case "$PROVIDER" in
  openrouter|anthropic|openai|google|deepseek|custom) ;;
  *) die "Unsupported provider: $PROVIDER" ;;
esac
[[ "$API_PORT" =~ ^[0-9]+$ ]] || die "--port must be numeric"

os_name() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Linux*) echo linux ;;
    Darwin*) echo macos ;;
    CYGWIN*|MINGW*|MSYS*) echo windows-shell ;;
    *) echo unknown ;;
  esac
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null || grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

require_cmd() { command -v "$1" >/dev/null 2>&1; }

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    return 1
  fi
}

ensure_docker() {
  local os="$1"
  local started="0"

  if require_cmd docker; then
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    # Docker exists but daemon not running — try to start it
    log "Docker is installed but not running. Attempting to start..."
    case "$os" in
      linux)
        if command -v systemctl >/dev/null 2>&1; then
          sudo systemctl enable --now docker 2>/dev/null || true
        elif command -v service >/dev/null 2>&1; then
          sudo service docker start 2>/dev/null || true
        fi
        ;;
      macos)
        open -a Docker 2>/dev/null || true
        log "Opening Docker Desktop. It may take a minute..."
        ;;
      windows-shell)
        warn "Start Docker Desktop manually and retry."
        return 1
        ;;
    esac
    for _ in $(seq 1 30); do
      if docker info >/dev/null 2>&1; then
        ok "Docker daemon is now running"
        return 0
      fi
      sleep 2
    done
    warn "Could not start Docker daemon automatically."
    cat <<EOF
Try manually:
  Linux:   sudo systemctl start docker
  macOS:   open -a Docker
  Windows: Open Docker Desktop from Start Menu
EOF
    return 1
  fi

  log "Docker not found. Installing for $os..."
  case "$os" in
    linux)
      if is_wsl; then
        log "WSL detected: installing Docker Engine directly"
      fi
      # Install curl if missing
      if ! require_cmd curl; then
        if command -v apt-get >/dev/null 2>&1; then
          sudo apt-get update -qq && sudo apt-get install -y -qq curl
        elif command -v yum >/dev/null 2>&1; then
          sudo yum install -y curl
        elif command -v apk >/dev/null 2>&1; then
          apk add curl
        fi
      fi
      if curl -fsSL https://get.docker.com | sudo sh; then
        sudo usermod -aG docker "$(whoami 2>/dev/null || echo "$USER")" 2>/dev/null || true
        if command -v systemctl >/dev/null 2>&1; then
          sudo systemctl enable --now docker 2>/dev/null || true
        elif command -v service >/dev/null 2>&1; then
          sudo service docker start 2>/dev/null || true
        fi
        for _ in $(seq 1 30); do
          if docker info >/dev/null 2>&1; then
            started="1"
            break
          fi
          sleep 2
        done
      fi
      ;;
    macos)
      local arch; arch="$(uname -m 2>/dev/null || echo x86_64)"
      local dmg_arch="amd64"
      if [[ "$arch" == "arm64" ]]; then
        dmg_arch="arm64"
      fi
      if require_cmd brew; then
        brew install --cask docker
      else
        log "Homebrew not found. Downloading Docker Desktop..."
        local dmg="/tmp/Docker.dmg"
        curl -L --max-time 300 -o "$dmg" "https://desktop.docker.com/mac/main/${dmg_arch}/Docker.dmg" || {
          warn "Download failed. Install Docker Desktop manually."
          warn "  https://docs.docker.com/desktop/install/mac-install/"
          return 1
        }
        if [[ ! -s "$dmg" ]]; then
          warn "Downloaded file is empty. URL may have changed."
          warn "  Install Docker Desktop manually: https://docs.docker.com/desktop/install/mac-install/"
          rm -f "$dmg"
          return 1
        fi
        sudo hdiutil attach "$dmg" -quiet 2>/dev/null || true
        if [ -d "/Volumes/Docker" ]; then
          cp -R "/Volumes/Docker/Docker.app" "/Applications" 2>/dev/null || true
          sudo hdiutil detach "/Volumes/Docker" -quiet 2>/dev/null || true
        fi
        rm -f "$dmg"
      fi
      open -a Docker 2>/dev/null || true
      log "Docker Desktop installed. Waiting for it to start..."
      for _ in $(seq 1 60); do
        if docker info >/dev/null 2>&1; then
          started="1"
          break
        fi
        sleep 5
      done
      ;;
    windows-shell)
      warn "Windows shell detected. Use install.ps1 for native Windows install."
      warn "Or install Docker Desktop manually: https://docs.docker.com/desktop/install/windows-install/"
      return 1
      ;;
    *)
      warn "Unsupported OS: $os. Install Docker manually."
      return 1
      ;;
  esac

  if [[ "$started" == "1" ]]; then
    ok "Docker installed and running"
  else
    warn "Docker installed but may need a restart or may not be running."
    warn "If Docker daemon is not running, try:"
    warn "  Linux: sudo systemctl start docker"
    warn "  macOS: open -a Docker"
    warn "Then re-run this installer."
    # Check if we at least have the docker binary now
    if require_cmd docker; then
      return 0
    fi
    return 1
  fi
}

prompt_default() {
  local var_name="$1" label="$2" default="$3" secret="${4:-0}" value=""
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    printf -v "$var_name" '%s' "$default"
    return
  fi
  if (: </dev/tty) 2>/dev/null; then
    exec < /dev/tty
    if [[ "$secret" == "1" ]]; then
      printf "%s [%s]: " "$label" "press enter to skip"
      read -r -s value || true
      printf "\n"
    else
      printf "%s [%s]: " "$label" "$default"
      read -r value || true
    fi
    value="${value:-$default}"
    printf -v "$var_name" '%s' "$value"
  else
    printf -v "$var_name" '%s' "$default"
  fi
}

random_hex() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 24
  elif command -v python3 >/dev/null 2>&1; then python3 - <<'PY'
import secrets
print(secrets.token_hex(24))
PY
  else date +%s | sha256sum | cut -c1-48
  fi
}

port_in_use() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1 && return 0; fi
  if command -v ss >/dev/null 2>&1; then ss -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)${port}$" && return 0; fi
  if command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 "$port" >/dev/null 2>&1 && return 0; fi
  return 1
}

resolve_port() {
  if port_in_use "$API_PORT"; then
    if [[ "$NONINTERACTIVE" == "1" ]]; then
      die "Port $API_PORT is already in use. Re-run with --port <free-port>."
    fi
    warn "Port $API_PORT is already in use."
    if (: </dev/tty) 2>/dev/null; then
      exec < /dev/tty
      for candidate in 8643 8644 18642 28642; do
        if ! port_in_use "$candidate"; then
          printf "Use free port %s instead? [Y/n]: " "$candidate"
          read -r ans || true
          case "${ans:-Y}" in y|Y|yes|YES) API_PORT="$candidate"; ok "Using port $API_PORT"; return ;; esac
        fi
      done
    fi
    die "Choose a free port with --port <port>."
  fi
}

safe_write() {
  local path="$1"
  if [[ -f "$path" && "$FORCE" != "1" ]]; then
    warn "Keeping existing $path. Use --force to overwrite."
    return 1
  fi
  return 0
}

preflight() {
  local os; os="$(os_name)"
  log "Hermes Docker Installer v$VERSION"
  local wsl_suffix=""
  is_wsl && wsl_suffix=" / WSL"
  log "Detected OS: ${os}${wsl_suffix}"

  if [[ "$SKIP_BUILD" == "1" ]]; then
    if require_cmd docker && docker info >/dev/null 2>&1 && COMPOSE="$(compose_cmd)"; then
      ok "Docker is ready"
    else
      COMPOSE=""
      warn "Docker is not available; --skip-build will generate files without validating Compose config."
    fi
    return
  fi

  require_cmd docker || ensure_docker "$os" || exit 1
  COMPOSE="$(compose_cmd)" || die "Docker Compose is required. Install Docker Compose v2 / Docker Desktop."

  if ! docker info >/dev/null 2>&1; then
    warn "Docker daemon is not responding. Attempting to start..."
    case "$os" in
      linux)
        if command -v systemctl >/dev/null 2>&1; then
          sudo systemctl enable --now docker 2>/dev/null || true
        elif command -v service >/dev/null 2>&1; then
          sudo service docker start 2>/dev/null || true
        fi
        ;;
      macos)
        open -a Docker 2>/dev/null || true
        ;;
      windows-shell)
        warn "Open Docker Desktop from Start Menu and enable WSL2 backend."
        ;;
    esac
    for _ in $(seq 1 30); do
      if docker info >/dev/null 2>&1; then
        ok "Docker daemon is now running"
        break
      fi
      sleep 2
    done
    if ! docker info >/dev/null 2>&1; then
      cat <<EOF
Docker is installed but not reachable.

Common fixes:
  Linux:   sudo systemctl start docker
  Linux:   sudo usermod -aG docker \$USER   # then log out/in
  macOS:   Open Docker Desktop and wait until it is running
  Windows: Open Docker Desktop from Start Menu and enable WSL2 backend
EOF
      exit 1
    fi
  fi
  ok "Docker is ready"
}

make_env() {
  mkdir -p "$INSTALL_DIR/workspace" "$INSTALL_DIR/bin"
  cd "$INSTALL_DIR"

  local api_key="" api_server_key="${API_SERVER_KEY:-$(random_hex)}"
  case "$PROVIDER" in
    openrouter) api_key="${OPENROUTER_API_KEY:-}" ;;
    anthropic) api_key="${ANTHROPIC_API_KEY:-}" ;;
    openai) api_key="${OPENAI_API_KEY:-}" ;;
    google) api_key="${GOOGLE_API_KEY:-${GEMINI_API_KEY:-}}" ;;
    deepseek) api_key="${DEEPSEEK_API_KEY:-}" ;;
    custom) api_key="${CUSTOM_API_KEY:-}" ;;
  esac

  if [[ ! -f .env || "$FORCE" == "1" ]]; then
    if [[ -f .env ]]; then
      log "Backing up existing .env to .env.bak"
      cp .env .env.bak
    fi
    if [[ -z "$api_key" ]]; then
      warn "No API key provided. Hermes will install, but model calls will fail until you edit $INSTALL_DIR/.env."
    elif [[ ${#api_key} -lt 12 ]]; then
      warn "API key looks unusually short. Continuing, but verify it in $INSTALL_DIR/.env if model calls fail."
    fi
    local openrouter_key="" anthropic_key="" openai_key="" google_key="" gemini_key="" deepseek_key="" custom_key=""
    case "$PROVIDER" in
      openrouter) openrouter_key="$api_key" ;;
      anthropic) anthropic_key="$api_key" ;;
      openai) openai_key="$api_key" ;;
      google) google_key="$api_key"; gemini_key="$api_key" ;;
      deepseek) deepseek_key="$api_key" ;;
      custom) custom_key="$api_key" ;;
    esac

    cat > .env <<EOF
# Generated by Hermes Docker Installer v$VERSION
COMPOSE_PROJECT_NAME=$PROJECT_NAME
MODEL_PROVIDER=$PROVIDER
MODEL_NAME=$MODEL
API_SERVER_PORT=$API_PORT
API_SERVER_KEY=$api_server_key
INSTALL_BROWSER=$INSTALL_BROWSER
HERMES_VERSION=$HERMES_VERSION

# Provider keys. Fill only the provider you use.
OPENROUTER_API_KEY=$openrouter_key
ANTHROPIC_API_KEY=$anthropic_key
OPENAI_API_KEY=$openai_key
GOOGLE_API_KEY=$google_key
GEMINI_API_KEY=$gemini_key
DEEPSEEK_API_KEY=$deepseek_key
CUSTOM_API_KEY=$custom_key
CUSTOM_BASE_URL=${CUSTOM_BASE_URL:-}
EOF
    chmod 600 .env || true
    ok "Created .env"
  else
    warn "Keeping existing .env"
  fi
}

write_files() {
  cd "$INSTALL_DIR"

  if safe_write Dockerfile; then
    cat > Dockerfile <<'EOF'
# Stage 1: Builder — install Hermes + Python deps
ARG PYTHON_VERSION=3.12-slim-bookworm
FROM python:${PYTHON_VERSION} AS builder
ARG INSTALL_BROWSER=0
ARG HERMES_VERSION=v2026.5.29.2
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
FROM python:${PYTHON_VERSION}
ARG INSTALL_BROWSER=0
ENV DEBIAN_FRONTEND=noninteractive \
    HADES_HOME=/root/.hermes \
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
EOF
  fi

  if safe_write bootstrap.sh; then
    cat > bootstrap.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
export HADES_HOME="${HADES_HOME:-/root/.hermes}"
export PATH="/venv/bin:/root/.local/bin:$PATH"
mkdir -p "$HADES_HOME" /workspace "$HADES_HOME/logs"

MODEL_PROVIDER="${MODEL_PROVIDER:-openrouter}"
MODEL_NAME="${MODEL_NAME:-deepseek/deepseek-v4-flash:free}"
if [[ -z "${API_SERVER_KEY:-}" ]]; then
  echo "ERROR: API_SERVER_KEY is not set. Aborting." >&2
  exit 1
fi
API_SERVER_PORT="${API_SERVER_PORT:-8642}"
CUSTOM_BASE_URL="${CUSTOM_BASE_URL:-}"

if [[ ! -f "$HADES_HOME/.env" ]]; then
  cat > "$HADES_HOME/.env" <<EOENV
API_SERVER_KEY=$API_SERVER_KEY
GATEWAY_ALLOW_ALL_USERS=${GATEWAY_ALLOW_ALL_USERS:-true}
PLAYWRIGHT_BROWSERS_PATH=/root/.cache/ms-playwright
EOENV

  # Write only the relevant provider key(s)
  case "$MODEL_PROVIDER" in
    openrouter) echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}" >> "$HADES_HOME/.env" ;;
    anthropic)  echo "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}" >> "$HADES_HOME/.env" ;;
    openai)     echo "OPENAI_API_KEY=${OPENAI_API_KEY:-}" >> "$HADES_HOME/.env" ;;
    google)
      echo "GOOGLE_API_KEY=${GOOGLE_API_KEY:-}" >> "$HADES_HOME/.env"
      echo "GEMINI_API_KEY=${GEMINI_API_KEY:-}" >> "$HADES_HOME/.env" ;;
    deepseek)   echo "DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-}" >> "$HADES_HOME/.env" ;;
    custom)
      echo "CUSTOM_API_KEY=${CUSTOM_API_KEY:-}" >> "$HADES_HOME/.env"
      echo "CUSTOM_BASE_URL=${CUSTOM_BASE_URL:-}" >> "$HADES_HOME/.env" ;;
  esac
  chmod 600 "$HADES_HOME/.env" || true
fi

if [[ ! -f "$HADES_HOME/config.yaml" ]]; then
  cat > "$HADES_HOME/config.yaml" <<EOCFG
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
fi

exec "$@"
EOF
    chmod +x bootstrap.sh
  fi

  if safe_write healthcheck.sh; then
    cat > healthcheck.sh <<'EOF'
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
EOF
    chmod +x healthcheck.sh
  fi

  if safe_write docker-compose.yml; then
    cat > docker-compose.yml <<'EOF'
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
    ports:
      - "127.0.0.1:${API_SERVER_PORT:-8642}:${API_SERVER_PORT:-8642}"
    volumes:
      - hermes_home:/root/.hermes
      - ./workspace:/workspace
    stdin_open: true
    tty: true
    restart: unless-stopped
    command: ["hermes", "gateway", "run"]

volumes:
  hermes_home:
EOF
  fi

  if safe_write bin/hades; then
    cat > bin/hades <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"
if docker compose version >/dev/null 2>&1; then DC=(docker compose); else DC=(docker-compose); fi
cmd="${1:-help}"; shift || true
case "$cmd" in
  start) "${DC[@]}" up -d "$@" ;;
  stop) "${DC[@]}" stop "$@" ;;
  restart) "${DC[@]}" restart "$@" ;;
  status) "${DC[@]}" ps "$@" ;;
  logs) "${DC[@]}" logs -f hermes "$@" ;;
  cli) "${DC[@]}" exec hermes hermes "$@" ;;
  shell) "${DC[@]}" exec hermes bash "$@" ;;
  build) "${DC[@]}" build "$@" ;;
  update) "${DC[@]}" build --pull && "${DC[@]}" up -d ;;
  down) "${DC[@]}" down "$@" ;;
  reset) "${DC[@]}" down -v "$@" ;;
  url) grep -m1 "^API_SERVER_PORT=" .env 2>/dev/null | cut -d= -f2 | xargs -I{} echo http://localhost:{} || echo http://localhost:8642 ;;
  key) grep -m1 "^API_SERVER_KEY=" .env 2>/dev/null | cut -d= -f2- ;;
  *)
    cat <<HELP
Hades helper
Usage: hades <command>
Commands:
  start    Start Hermes gateway/API server
  stop     Stop container
  restart  Restart container
  status   Show status
  logs     Follow logs
  cli      Open interactive Hermes CLI
  shell    Open container shell
  build    Rebuild image
  update   Pull/rebuild/restart
  down     Stop and remove container/network, keep data volume
  reset    Remove container and data volume
  url      Print API server URL
  key      Print API server key
HELP
    ;;
esac
EOF
    chmod +x bin/hades
  fi

  # Shell configuration & Path setup (Nous-Style)
  if [ "$(id -u)" -eq 0 ]; then
    if [ ! -L "/usr/local/bin/hades" ]; then
      ln -sf "$INSTALL_DIR/bin/hades" "/usr/local/bin/hades"
      ok "Linked hades to /usr/local/bin/hades"
    fi
  else
    local command_link_dir="$HOME/.local/bin"
    mkdir -p "$command_link_dir"
    ln -sf "$INSTALL_DIR/bin/hades" "$command_link_dir/hades"
    
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^$command_link_dir$"; then
      local shell_configs=()
      local is_fish=false
      local login_shell
      login_shell="$(basename "${SHELL:-/bin/bash}")"
      case "$login_shell" in
        zsh)
          [ -f "$HOME/.zshrc" ] && shell_configs+=("$HOME/.zshrc")
          [ -f "$HOME/.zprofile" ] && shell_configs+=("$HOME/.zprofile")
          if [ ${#shell_configs[@]} -eq 0 ]; then
            touch "$HOME/.zshrc"
            shell_configs+=("$HOME/.zshrc")
          fi
          ;;
        bash)
          [ -f "$HOME/.bashrc" ] && shell_configs+=("$HOME/.bashrc")
          [ -f "$HOME/.bash_profile" ] && shell_configs+=("$HOME/.bash_profile")
          ;;
        fish)
          is_fish=true
          local fish_config="$HOME/.config/fish/config.fish"
          mkdir -p "$(dirname "$fish_config")"
          touch "$fish_config"
          ;;
        *)
          [ -f "$HOME/.bashrc" ] && shell_configs+=("$HOME/.bashrc")
          [ -f "$HOME/.zshrc" ] && shell_configs+=("$HOME/.zshrc")
          ;;
      esac
      [ "$is_fish" = "false" ] && [ -f "$HOME/.profile" ] && shell_configs+=("$HOME/.profile")

      # shellcheck disable=SC2016
      local path_line='export PATH="$HOME/.local/bin:$PATH"'
      for config_file in "${shell_configs[@]}"; do
        if ! grep -v '^[[:space:]]*#' "$config_file" 2>/dev/null | grep -qE 'PATH=.*\.local/bin'; then
          {
            echo ""
            echo "# Hades Installer - ensure ~/.local/bin is on PATH"
            echo "$path_line"
          } >> "$config_file"
          ok "Added ~/.local/bin to PATH in $config_file"
        fi
      done

      if [ "$is_fish" = "true" ]; then
        if ! grep -q 'fish_add_path.*\.local/bin' "$fish_config" 2>/dev/null; then
          {
            echo ""
            echo "# Hades Installer - ensure ~/.local/bin is on PATH"
            # shellcheck disable=SC2016
            echo 'fish_add_path "$HOME/.local/bin"'
          } >> "$fish_config"
          ok "Added ~/.local/bin to PATH in $fish_config"
        fi
      fi
    fi
  fi

  if safe_write README.md; then
    cat > README.md <<EOF
# Hades

Installed by Hades Public Installer v$VERSION.

## Commands

    ./bin/hades start
    ./bin/hades cli
    ./bin/hades logs
    ./bin/hades status
    ./bin/hades restart
    ./bin/hades update
    ./bin/hades down

## API Server

URL:

    http://localhost:$API_PORT

API key:

    ./bin/hades key

## Config

Edit provider/model/API keys:

    $INSTALL_DIR/.env

Then restart:

    ./bin/hades restart

## Workspace

Host folder:

    $INSTALL_DIR/workspace

Container folder:

    /workspace

## Full reset

This deletes Hermes container data:

    ./bin/hades reset
EOF
  fi
}

wait_for_health() {
  local url="http://127.0.0.1:${API_PORT}/health"
  log "Waiting for Hermes API healthcheck: $url"
  for _ in $(seq 1 60); do
    if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
      ok "Hermes API server is healthy"
      return 0
    fi
    sleep 2
  done
  warn "Healthcheck did not pass within 120 seconds. Showing recent logs:"
  $COMPOSE logs --tail 80 hermes || true
  return 1
}

build_and_start() {
  cd "$INSTALL_DIR"
  if [[ "$SKIP_BUILD" == "1" ]]; then
    log "Generated files only; skipping Docker build/start."
    if [[ -n "${COMPOSE:-}" ]]; then
      $COMPOSE config >/dev/null
      ok "Docker Compose config is valid"
    else
      warn "Skipped Docker Compose validation because Docker is not available."
    fi
    return
  fi
  log "Building Docker image. Add --browser for Playwright/Chromium (~450 MB extra, default: skip)."
  
  local build_log
  build_log="$(mktemp 2>/dev/null || echo "/tmp/hades-build.$$.log")"
  if ! $COMPOSE build > "$build_log" 2>&1; then
    err "Failed to build Docker images."
    err "Build logs:"
    sed 's/^/    /' "$build_log" >&2
    rm -f "$build_log"
    exit 1
  fi
  rm -f "$build_log"

  if [[ "$START_AFTER_INSTALL" == "1" ]]; then
    log "Starting Hermes gateway/API server..."
    if ! $COMPOSE up -d; then
      die "Failed to start container stack."
    fi
    sleep 3
    $COMPOSE ps
    wait_for_health || true
  fi
}

uninstall() {
  if [[ ! -d "$INSTALL_DIR" ]]; then
    warn "Install directory not found: $INSTALL_DIR"
    warn "Nothing to uninstall."
    return 0
  fi
  cd "$INSTALL_DIR"
  local c=""
  if ! c="$(compose_cmd)"; then
    warn "Docker Compose not found. Skipping stack shutdown."
    warn "Files kept at: $INSTALL_DIR"
    return
  fi
  if ! docker info >/dev/null 2>&1; then
    warn "Docker daemon is not running. Skipping stack shutdown."
    warn "Files kept at: $INSTALL_DIR"
    return
  fi
  $c down --remove-orphans || true
  if [[ "$NONINTERACTIVE" == "1" ]]; then
    warn "Kept Docker volume. To remove data: cd $INSTALL_DIR && $c down -v --remove-orphans"
    return
  fi
  if (: </dev/tty) 2>/dev/null; then
    exec < /dev/tty
    printf "Remove Hermes Docker data volume too? This deletes config/sessions/memory. [y/N]: "
    read -r ans || true
    case "$ans" in y|Y|yes|YES) $c down -v --remove-orphans; ok "Removed stack and data volume" ;; *) ok "Removed stack, kept data volume" ;; esac
  else
    warn "Kept Docker volume (non-interactive). To remove data: cd $INSTALL_DIR && $c down -v --remove-orphans"
  fi
}

main() {
  if [[ "$UNINSTALL" == "1" ]]; then uninstall; exit 0; fi
  preflight
  if [[ "$START_AFTER_INSTALL" == "1" ]]; then
    resolve_port
  fi
  make_env
  write_files
  build_and_start
  cat <<EOF

${GREEN}${BOLD}Hermes Agent Docker is installed.${NC}

Install directory:
  $INSTALL_DIR

Main helper:
  $INSTALL_DIR/bin/hades

Open Hermes CLI:
  cd $INSTALL_DIR && ./bin/hades cli

View logs:
  cd $INSTALL_DIR && ./bin/hades logs

API server:
  http://localhost:$API_PORT

API key:
  cd $INSTALL_DIR && ./bin/hades key

Edit API keys/model:
  $INSTALL_DIR/.env

EOF
}

main "$@"
