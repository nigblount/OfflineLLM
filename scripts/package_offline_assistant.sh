#!/usr/bin/env bash
set -euo pipefail

# Package the offline AI assistant stack into offline-assistant.tar.gz

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_DIR="$(mktemp -d)"
IMAGES_DIR="$STAGING_DIR/images"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$IMAGES_DIR"

# Copy core scripts and config
cp "$REPO_ROOT/scripts/setup.sh" "$STAGING_DIR/"
cp "$REPO_ROOT/scripts/start_offline_assistant.sh" "$STAGING_DIR/"
cp "$REPO_ROOT/scripts/launch.sh" "$STAGING_DIR/"
cp "$REPO_ROOT/scripts/install_shortcut.sh" "$STAGING_DIR/"
cp "$REPO_ROOT/configs/OfflineLLM.desktop" "$STAGING_DIR/"
cp "$REPO_ROOT/.env.example" "$STAGING_DIR/"
mkdir -p "$STAGING_DIR/configs/openwebui"
cp "$REPO_ROOT/configs/openwebui/settings.yaml" "$STAGING_DIR/configs/openwebui/"
cp -r "$REPO_ROOT/configs/openwebui/models" "$STAGING_DIR/configs/openwebui/"

# Copy services and dockerfiles
mkdir -p "$STAGING_DIR/services"
cp -r "$REPO_ROOT/services/preview_service" "$STAGING_DIR/services/"
cp -r "$REPO_ROOT/docker" "$STAGING_DIR/"

# Compose file
cp "$REPO_ROOT/docker-compose.yaml" "$STAGING_DIR/"


# Save Docker images

echo "Saving Docker images..."

docker save offline-llm/preview:1.0 -o "$IMAGES_DIR/preview-service.tar"

docker save offline-llm/webui:1.0 -o "$IMAGES_DIR/open-webui.tar"

docker save ollama/ollama:0.9.5 -o "$IMAGES_DIR/ollama.tar"

# Create archive

tar -C "$STAGING_DIR" -czf offline-assistant.tar.gz .

echo "Created archive offline-assistant.tar.gz"
