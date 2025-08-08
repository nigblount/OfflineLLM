#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Offline LLM Assistant"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
DESKTOP_FILE="$DESKTOP_DIR/offline-llm.desktop"

mkdir -p "$DESKTOP_DIR"

# Write a desktop entry that calls launch.sh from this repo
cat > "$DESKTOP_FILE" <<'EOF2'
[Desktop Entry]
Type=Application
Name=Offline LLM Assistant
Comment=Chat with Qwen3-32B offline via Open WebUI
Terminal=false
Categories=Utility;X-AI;
# Exec will be replaced below with the absolute path
Exec=__REPO__/scripts/launch.sh
Icon=utilities-terminal
EOF2

# Replace placeholder with actual path
sed -i "s|__REPO__|$REPO_ROOT|g" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

echo "Installed desktop launcher at: $DESKTOP_FILE"
echo "Find it in your app launcher as: $APP_NAME"

# Optional: install a user systemd service pointing to launch.sh
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
SERVICE_FILE="$SYSTEMD_USER_DIR/offline-llm.service"
cat > "$SERVICE_FILE" <<EOF2
[Unit]
Description=Offline LLM Assistant
After=network.target docker.service

[Service]
ExecStart=$REPO_ROOT/scripts/launch.sh --headless
WorkingDirectory=$REPO_ROOT
Restart=on-failure
RestartSec=10
Environment=DOCKER_HOST=unix:///var/run/docker.sock

[Install]
WantedBy=default.target
EOF2

systemctl --user daemon-reload
echo "User service file installed: $SERVICE_FILE"
echo "Enable it with: systemctl --user enable --now offline-llm.service"
