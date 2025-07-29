#!/usr/bin/env bash
set -euo pipefail

# Install Docker Engine and Docker Compose plugin
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

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
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/nvidia-container-toolkit.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    sudo apt-get update
    sudo apt-get install -y nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
fi

# Log into Hugging Face CLI
if ! command -v huggingface-cli > /dev/null; then
    pip install --user --upgrade huggingface-hub
    export PATH="$HOME/.local/bin:$PATH"
fi

if [ -z "${HF_TOKEN:-}" ]; then
    read -rp "Enter your Hugging Face token: " HF_TOKEN
fi
huggingface-cli login --token "$HF_TOKEN" --stdin <<< "$HF_TOKEN"

# Download the Qwen2-32B model
mkdir -p models
huggingface-cli download Qwen/Qwen2-32B --local-dir models/Qwen2-32B --local-dir-use-symlinks False

# Pull required Docker images
docker pull vllm/vllm-openai:v0.10.0
docker pull ghcr.io/open-webui/open-webui:main

echo "Setup complete. Start the stack with:\n  docker compose -f docker-compose.vllm.yaml up -d"