#!/usr/bin/env bash
set -euo pipefail

# Install Docker Engine and Docker Compose plugin
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg; then
    echo "[ERROR] Failed to download Docker GPG key" >&2
    exit 1
fi

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

# Install NVIDIA Container Toolkit
if ! command -v nvidia-smi > /dev/null; then
    echo "NVIDIA drivers are required but not detected. Please install them first." >&2
else
    distribution=$( . /etc/os-release; echo $ID$VERSION_ID )
    if ! curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit.gpg; then
        echo "[ERROR] Failed to download NVIDIA GPG key" >&2
        exit 1
    fi
    if ! curl -fsSL https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list; then
        echo "[ERROR] Failed to fetch NVIDIA container repository list" >&2
        exit 1
    fi
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
fi

echo "Setup complete. Start the stack with:\n  ./scripts/launch.sh"
