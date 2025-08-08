#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  - Click desktop icon → runs without args, opens browser
#  - systemd user service → passes --headless, no browser pop
OPEN_BROWSER=1
if [[ "${1:-}" == "--headless" ]]; then OPEN_BROWSER=0; fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Ensure Docker is running (best-effort)
if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not available. Please start Docker and retry." >&2
  exit 1
fi

# Create data dirs expected by compose
mkdir -p data/webui data/webui/embeddings data/preview

# Start or update the stack
docker compose -f docker-compose.yaml up -d --build

# Optionally open Open WebUI in a browser
if [[ "$OPEN_BROWSER" -eq 1 ]]; then
  if command -v xdg-open >/dev/null; then
    xdg-open "http://localhost:8080" >/dev/null 2>&1 || true
  fi
fi

echo "Offline LLM is running. Open http://localhost:8080"
