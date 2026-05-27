#!/usr/bin/env bash
# Hermes Docker Uninstaller — robust version
set -Eeuo pipefail

INSTALL_DIR="${1:-${HERMES_DOCKER_HOME:-$HOME/.hermes-docker}}"
REMOVE_FILES="${REMOVE_FILES:-0}"
REMOVE_DATA="${REMOVE_DATA:-0}"

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
    echo "Start Docker first, then re-run uninstall, or manually:"
    echo "  rm -rf $INSTALL_DIR"
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
  echo "  REMOVE_DATA=1 $0"
  echo ""
  echo "To remove all files too:"
  echo "  REMOVE_FILES=1 $0"
fi
