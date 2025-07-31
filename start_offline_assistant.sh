#!/usr/bin/env bash
set -euo pipefail

# Change to the directory where this script resides
cd "$(dirname "$(realpath "$0")")"

# Start the Docker Compose stack
docker compose up -d

# Wait for Open WebUI to become available
printf "Waiting for Open WebUI..."
until curl -fs http://localhost:3000 >/dev/null 2>&1; do
  printf "."
  sleep 2
done
printf " done\n"

# Launch the browser
xdg-open http://localhost:3000 >/dev/null 2>&1 &
