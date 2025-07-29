#!/usr/bin/env bash
set -euo pipefail

# Package the offline AI assistant stack into offline-assistant.tar.gz

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="$(mktemp -d)"
IMAGES_DIR="$STAGING_DIR/images"
trap 'rm -rf "$STAGING_DIR"' EXIT

mkdir -p "$IMAGES_DIR"

# Copy core scripts and config
cp "$REPO_ROOT/setup.sh" "$STAGING_DIR/"
cp "$REPO_ROOT/start_offline_assistant.sh" "$STAGING_DIR/"
cp "$REPO_ROOT/OfflineAssistant.desktop" "$STAGING_DIR/"
cp "$REPO_ROOT/.env.example" "$STAGING_DIR/"

# Copy preview service and infrastructure files
mkdir -p "$STAGING_DIR/services"
cp -r "$REPO_ROOT/services/preview_service" "$STAGING_DIR/services/"
cp -r "$REPO_ROOT/infra" "$STAGING_DIR/"

# Compose files
cp "$REPO_ROOT/docker-compose.yml" "$STAGING_DIR/"
if [[ -f "$REPO_ROOT/docker-compose.vllm.yaml" ]]; then
  cp "$REPO_ROOT/docker-compose.vllm.yaml" "$STAGING_DIR/"
fi

# Optional icon
if [[ -f "$REPO_ROOT/openwebui_icon.png" ]]; then
  cp "$REPO_ROOT/openwebui_icon.png" "$STAGING_DIR/"
fi

# Save Docker images

echo "Saving Docker images..."

docker save offline-llm/preview:1.0 -o "$IMAGES_DIR/preview-service.tar"

docker save ghcr.io/open-webui/open-webui:ollama -o "$IMAGES_DIR/open-webui.tar"

if docker image inspect vllm/vllm-openai:v0.10.0 >/dev/null 2>&1; then
  docker save vllm/vllm-openai:v0.10.0 -o "$IMAGES_DIR/vllm.tar"
elif docker image inspect ollama/ollama:0.9.5 >/dev/null 2>&1; then
  docker save ollama/ollama:0.9.5 -o "$IMAGES_DIR/ollama.tar"
fi

# Create archive

tar -C "$STAGING_DIR" -czf offline-assistant.tar.gz .

echo "Created archive offline-assistant.tar.gz"
