#!/usr/bin/env bash
# Hermes Docker Uninstaller — robust version
set -Eeuo pipefail

INSTALL_DIR="${HERMES_DOCKER_HOME:-$HOME/.hermes-docker}"
REMOVE_FILES="${REMOVE_FILES:-0}"
REMOVE_DATA="${REMOVE_DATA:-0}"

usage() {
  cat <<'EOF'
Hermes Docker uninstaller

Usage:
  uninstall.sh [--dir PATH] [--remove-data] [--remove-files]

Options:
  --dir PATH       Install directory, default: ~/.hermes-docker
  --remove-data   Remove Docker volumes too
  --remove-files  Remove generated install directory too
  -h, --help      Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    --remove-data) REMOVE_DATA="1"; shift ;;
    --remove-files) REMOVE_FILES="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) INSTALL_DIR="$1"; shift ;;
  esac
done

if [[ ! -d "$INSTALL_DIR" ]]; then
  echo "Hermes Docker install directory not found: $INSTALL_DIR"
  echo "Nothing to uninstall."
  exit 0
fi

cd "$INSTALL_DIR"

# Detect Docker Compose
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "WARN: Docker Compose not found. Skipping container shutdown."
  echo "Remove $INSTALL_DIR manually: rm -rf $INSTALL_DIR"
  # Don't exit — still try to clean up files
  DC=()
fi

  # Stop containers (if compose available)
  if [[ ${#DC[@]} -gt 0 ]]; then
    if docker info >/dev/null 2>&1; then
      echo "Stopping Hermes Docker stack..."
      if [[ "$REMOVE_DATA" == "1" ]]; then
        "${DC[@]}" down -v --remove-orphans 2>&1 || true
      else
        "${DC[@]}" down --remove-orphans 2>&1 || true
      fi
    else
      echo "WARN: Docker daemon is not running. Skipping container shutdown."
    fi
  fi

# Remove files
if [[ "$REMOVE_FILES" == "1" ]]; then
  rm -rf "$INSTALL_DIR"
  echo "Removed install directory: $INSTALL_DIR"
else
  echo "Stopped Hermes Docker stack. Files kept at: $INSTALL_DIR"
  echo ""
  echo "To remove data volume too:"
  echo "  $0 --remove-data"
  echo ""
  echo "To remove all files too:"
  echo "  $0 --remove-files"
fi
