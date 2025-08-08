#!/usr/bin/env bash
set -euo pipefail

OPEN_BROWSER=1
if [[ "${1:-}" == "--headless" ]]; then OPEN_BROWSER=0; fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Detect docker compose command
dc() {
  if command -v docker >/dev/null 2>&1; then
    docker compose "$@"
  else
    echo "Docker is not installed. Please install Docker and retry." >&2
    exit 1
  fi
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found; installing a minimal portable jq into .bin ..."
  mkdir -p .bin
  JQ_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
  curl -fsSL "$JQ_URL" -o .bin/jq && chmod +x .bin/jq
  export PATH="$REPO_ROOT/.bin:$PATH"
fi

# Quick docker daemon check
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not available. Please start Docker and retry." >&2
  read -rp "Press Enter to exit..." _
  exit 1
fi

# Create data dirs
mkdir -p data/webui data/preview data/ollama

# Start or update the stack
docker compose -f docker-compose.yaml up -d --build

# Decide which URL to open
SETUP_URL="http://localhost:5051/setup"
OPENWEBUI_PORT="${OPENWEBUI_PORT:-3000}"
WEBUI_URL="http://localhost:${OPENWEBUI_PORT}"

# If no config yet, guide user to setup on first run
if [[ "$OPEN_BROWSER" -eq 1 ]]; then
  if command -v xdg-open >/dev/null; then
    if [[ ! -f "$REPO_ROOT/data/config/.env" ]]; then
      xdg-open "$SETUP_URL" >/dev/null 2>&1 || true
    else
      xdg-open "$WEBUI_URL" >/dev/null 2>&1 || true
    fi
  fi
fi

echo "Offline LLM is running."
if [[ ! -f "$REPO_ROOT/data/config/.env" ]]; then
  echo "First run detected. Open $SETUP_URL to complete setup."
else
  echo "Open WebUI: $WEBUI_URL"
fi
