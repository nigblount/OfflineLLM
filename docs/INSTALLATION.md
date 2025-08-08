# Offline Qwen3-32B Inference Stack

This guide walks through setting up a fully containerized offline LLM stack for Czech business report analysis. It includes a Flask-based PDF preview service, an Ollama backend running Qwen3-32B, Open WebUI, and an optional Apache Tika server.

## Prerequisites
- **OS**: Ubuntu 22.04 LTS
- **GPU**: NVIDIA GPU with driver 535+ and CUDA 12.2
- **Hardware**: 50 GB free disk, 16 GB RAM
- **Tools**: Docker Engine & Compose, NVIDIA Container Toolkit, Git, curl

All commands assume a non-root user with `sudo` privileges.

## 1. Install System Packages
Update the system and install utilities:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl
```

Add Docker's repository using a keyring and install Docker Engine and the Compose plugin:
```bash
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \ 
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```
Verify Docker installation:
```bash
docker version
docker compose version
```

## 2. NVIDIA Drivers and Container Toolkit
Install the proprietary driver and toolkit:
```bash
sudo apt install -y nvidia-driver-535 nvidia-utils-535
sudo reboot
nvidia-smi
```
Install the container toolkit using a signed repo:
```bash
distribution=$( . /etc/os-release; echo $ID$VERSION_ID )
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  gpg --dearmor | sudo tee /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] \ 
  https://nvidia.github.io/libnvidia-container/$distribution/ /" | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```
Test with:
```bash
docker run --rm --gpus all nvidia/cuda:12.2.0-runtime-ubuntu22.04 nvidia-smi
```

## 3. Project Structure
Create a directory and initialise Git:
```bash
mkdir offline-llm && cd offline-llm
git init
```
Suggested layout:
```
offline-llm/
├── services/
│   └── preview_service/
├── models/
├── docker/
└── docs/
```

## 4. Base Docker Image
Create `docker/base.Dockerfile`:
```Dockerfile
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04
LABEL org.opencontainers.image.source="https://github.com/yourrepo/offline-llm" \
      org.opencontainers.image.description="Base image with Python3 and CUDA runtime"
RUN apt-get update && apt-get install -y python3 python3-pip git curl && rm -rf /var/lib/apt/lists/*
```
Build it:
```bash
docker build -f docker/base.Dockerfile -t offline-llm/base:1.0 .
```
Use it in another Dockerfile:
```Dockerfile
FROM offline-llm/base:1.0
```
Build a minimal image with the Qwen3-32B model and fill a volume:

```bash
docker build -f docker/model.Dockerfile -t qwen3-model:1.0 .
docker volume create qwen3-model
docker run --rm -v qwen3-model:/models/qwen3-32b qwen3-model:1.0
```


## 5. Docker Compose Stack
Create `docker-compose.yaml`:
```yaml
version: "3.9"
services:
  preview-service:
    build:
      context: .
      dockerfile: docker/preview_service.Dockerfile
    image: offline-llm/preview:1.0
    volumes:
      - preview_data:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      retries: 3
    restart: unless-stopped

  ollama:
    image: ollama/ollama:0.9.5
    command: ["ollama", "serve", "--model", "/models/qwen3-32b/Qwen3-32B-*.gguf"]
    ports:
      - "11434:11434"
    volumes:
      - qwen3-model:/models/qwen3-32b:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/models"]
      interval: 30s
      retries: 5
    deploy:
      device_requests:
        - driver: nvidia
          count: all
          capabilities: [gpu]
    restart: unless-stopped

  open-webui:
    image: ghcr.io/open-webui/open-webui:ollama
    ports:
      - "8080:8080"
    volumes:
      - webui_data:/app/backend/data
    depends_on:
      ollama:
        condition: service_started
      preview-service:
        condition: service_started
    restart: unless-stopped

  tika:
    image: apache/tika:3.2.1.0-full
    restart: unless-stopped

volumes:
  qwen3-model:
  webui_data:
  preview_data:
```


## 6. Preview Service Container
`services/preview_service/requirements.txt`:
```
fastapi==0.100.0
uvicorn[standard]==0.23.0
PyMuPDF==1.26.3
pdf2image==1.16.3
pytesseract==0.3.10
Pillow==9.5.0
```

`docker/preview_service.Dockerfile`:
```Dockerfile
FROM offline-llm/base:1.0
WORKDIR /app
RUN apt-get update && apt-get install -y \
    poppler-utils tesseract-ocr tesseract-ocr-ces \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5001
CMD ["python", "app.py"]
```

`services/preview_service/app.py` example:
```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/extract")
def extract():
    # handle uploaded file and return extracted text
    return jsonify({"text": "...", "language": "en"})
```

## 7. Launch the Stack
Copy `.env.example` to `.env` and set `WEBUI_SECRET`. Install the desktop shortcut and user service (optional):
```bash
chmod +x scripts/install_shortcut.sh
./scripts/install_shortcut.sh
```

Start the containers:
```bash
./scripts/launch.sh
```
Check status:
```bash
docker compose ps
```
Open WebUI at <http://localhost:8080>.

## 8. Maintenance Tips
- Keep images and host packages updated.
- Limit container privileges by running as non-root where possible.
- Use healthchecks and `restart: unless-stopped` to improve reliability.
- Consider a CI pipeline to rebuild images and scan for vulnerabilities.

## 9. Desktop launcher and systemd service
Run the installer to create a desktop shortcut and optional user service:

```bash
chmod +x scripts/install_shortcut.sh
./scripts/install_shortcut.sh
```

The launcher appears as **Offline LLM Assistant**. To keep the stack running after login, enable the service:

```bash
systemctl --user enable --now offline-llm.service
```

Ensure `unset DOCKER_HOST` is present in your `~/.bashrc` so Docker uses the default socket.
