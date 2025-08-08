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

echo "Building images (first run can take several minutes)..."
dc build --pull open-webui preview-service

echo "Starting services..."
dc up -d

echo "Waiting for services to become healthy..."
deadline=$((SECONDS+600))
services=(ollama preview-service open-webui)
for s in "${services[@]}"; do
  echo -n " - $s "
  while true; do
    status="$(dc ps --format json | jq -r ".[] | select(.Name==\"$s\") | .Health")"
    if [[ "$status" == "healthy" ]]; then
      echo "✓"
      break
    fi
    if (( SECONDS > deadline )); then
      echo "timed out"
      dc logs --no-log-prefix "$s" || true
      echo "Service '$s' failed to become healthy."
      exit 1
    fi
    echo -n "."
    sleep 3
  done
done

URL="http://localhost:3000"
echo "Offline LLM is running at: $URL"
if [[ "$OPEN_BROWSER" -eq 1 ]]; then
  if command -v xdg-open >/dev/null; then xdg-open "$URL" >/dev/null 2>&1 || true; fi
  if command -v gio >/dev/null; then gio open "$URL" >/dev/null 2>&1 || true; fi
fi
