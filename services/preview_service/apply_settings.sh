#!/usr/bin/env sh
set -eu

# read settings
CONFIG_DIR="/app/config"
SETTINGS="$CONFIG_DIR/settings.json"

MODE="$(jq -r '.mode // "offline"' "$SETTINGS")"
EMB_MODEL="$(jq -r '.emb_model // "intfloat/multilingual-e5-base"' "$SETTINGS")"

# If mode == build-online, rebuild open-webui image to bake embeddings
if [ "$MODE" = "build-online" ]; then
  echo "Rebuilding open-webui to bake embeddings ($EMB_MODEL) with online access..."
  cd /app/..
  docker compose build --no-cache open-webui || true
  docker compose up -d open-webui || true
else
  echo "Offline mode selected; restarting services with current images..."
  cd /app/..
  docker compose up -d
fi
