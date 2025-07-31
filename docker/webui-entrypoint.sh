#!/usr/bin/env bash
set -e

OLLAMA_URL="${OLLAMA_URL:-http://ollama:11434}"
PREVIEW_URL="${PREVIEW_SERVICE_URL:-http://preview-service:5001}"

echo "Waiting for Ollama at $OLLAMA_URL..."
until curl -sSf "$OLLAMA_URL/models" >/dev/null; do
  sleep 2
done
echo "Connected to Ollama at $OLLAMA_URL"

echo "Waiting for Preview Service at $PREVIEW_URL..."
until curl -sSf "$PREVIEW_URL/health" >/dev/null; do
  sleep 2
done
echo "Connected to Preview Service at $PREVIEW_URL"

DB_PATH="/app/backend/data/sqlite.db"
if [ ! -f "$DB_PATH" ]; then
  echo "Initializing chat database at $DB_PATH"
  touch "$DB_PATH"
else
  echo "Using existing chat database at $DB_PATH"
fi

echo "Starting Open WebUI"
exec "$@"