#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_step() {
  echo -e "\n=== $1 ===\n"
  date
}

log_step "System Packages"
sudo apt update && sudo apt upgrade -y --with-new-pkgs

log_step "GPU Drivers (NVIDIA)"
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "Current NVIDIA driver version: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)"
else
  echo "nvidia-smi not found; proceeding with driver installation"
fi
if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
  distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/$distribution/libnvidia-container.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
fi
sudo apt update
sudo apt install -y nvidia-driver-535 nvidia-container-toolkit
sudo systemctl restart docker

log_step "Docker Engine & Compose"
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
sudo sh /tmp/get-docker.sh
rm /tmp/get-docker.sh

mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose

docker --version
docker compose version

log_step "Python Requirements"
if [ -f "$REPO_ROOT/services/preview_service/requirements.txt" ]; then
  if grep -q 'pip install --no-cache-dir -r requirements.txt' "$REPO_ROOT/docker/preview_service.Dockerfile"; then
    echo "Verified pip install in docker/preview_service.Dockerfile"
  else
    echo "Warning: docker/preview_service.Dockerfile missing pip install line"
  fi
fi

log_step "Desktop Launcher"
desktop_file="${XDG_DATA_HOME:-$HOME/.local/share}/applications/offline-llm.desktop"
if [ ! -f "$desktop_file" ]; then
  mkdir -p "$(dirname "$desktop_file")"
  cat <<LAUNCHER > "$desktop_file"
[Desktop Entry]
Name=Offline LLM Assistant
Exec=$REPO_ROOT/scripts/launch.sh
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;
LAUNCHER
  chmod +x "$desktop_file"
fi

log_step "Restarting Offline LLM"
docker compose -f "$REPO_ROOT/docker-compose.yaml" pull
docker compose -f "$REPO_ROOT/docker-compose.yaml" build
docker compose -f "$REPO_ROOT/docker-compose.yaml" up -d
