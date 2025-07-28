# Offline Qwen3-32B Inference Stack

This guide walks through setting up a fully containerized offline LLM stack for Czech business report analysis. It includes a FastAPI PDF preview service, an Ollama backend running Qwen3-32B, Open WebUI, and an optional Apache Tika server.

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
├── infra/
└── docs/
```

## 4. Base Docker Image
Create `infra/base.Dockerfile`:
```Dockerfile
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04
LABEL org.opencontainers.image.source="https://github.com/yourrepo/offline-llm"
RUN apt-get update && apt-get install -y python3 python3-pip git curl \
    && rm -rf /var/lib/apt/lists/*
```
Build it:
```bash
docker build -f infra/base.Dockerfile -t offline-llm/base:1.0 .
```

## 5. Docker Compose Stack
Create `infra/docker-compose.yml`:
```yaml
version: "3.9"
services:
  preview-service:
    build:
      context: services/preview_service
      dockerfile: Dockerfile
    image: offline-llm/preview:1.0
    ports:
      - "5001:5001"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      retries: 3
    restart: unless-stopped

  ollama:
    image: ollama/ollama:0.9.5
    volumes:
      - qwen3-model:/models/qwen3-32b:ro
    command: >
      ollama serve --model /models/qwen3-32b/Qwen3-32B-*.gguf \
      --port 11434 --host 0.0.0.0 --log-level info
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/models"]
      interval: 30s
      timeout: 5s
      retries: 3
    restart: unless-stopped

  open-webui:
    image: ghcr.io/open-webui/open-webui:ollama
    ports:
      - "3000:8080"
    volumes:
      - openwebui-data:/app/backend/data
    depends_on:
      ollama:
        condition: service_healthy
    restart: unless-stopped

  tika:
    image: apache/tika:3.2.1.0-full
    restart: unless-stopped

volumes:
  qwen3-model:
    external: true
  openwebui-data:
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

`services/preview_service/Dockerfile`:
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
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "5001"]
```

`services/preview_service/server.py` example:
```python
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
import fitz
from pdf2image import convert_from_path
import pytesseract
from PIL import Image
import os

app = FastAPI(title="PDF Preview Service")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/preview/pdf-text")
def extract_pdf_text(filename: str):
    path = os.path.join("uploads", filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    doc = fitz.open(path)
    text = "".join(page.get_text("text") for page in doc)
    return {"text": text}

@app.get("/preview/thumbnail")
def get_pdf_thumbnail(filename: str, page: int = 0):
    path = os.path.join("uploads", filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    img = convert_from_path(path, first_page=page+1, last_page=page+1)[0]
    out = f"/tmp/{filename}_p{page}.png"
    img.save(out, "PNG")
    return FileResponse(out)
```

## 7. Launch the Stack
Build and start the containers:
```bash
docker compose -f infra/docker-compose.yml up --build -d
```
Check status:
```bash
docker compose -f infra/docker-compose.yml ps
```
Open WebUI at <http://localhost:3000>.

## 8. Maintenance Tips
- Keep images and host packages updated.
- Limit container privileges by running as non-root where possible.
- Use healthchecks and `restart: unless-stopped` to improve reliability.
- Consider a CI pipeline to rebuild images and scan for vulnerabilities.
