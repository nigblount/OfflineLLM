# OfflineLLM

OfflineLLM bundles Open WebUI with the Qwen3-32B model, a PDF preview microservice, and optional Apache Tika for rich document parsing.  The stack runs fully offline using Docker Compose with NVIDIA GPU acceleration and supports loading additional local GGUF models through Ollama.

## Repository layout

```
/docker            # Dockerfiles for images
/services          # Application source code (preview service)
/scripts           # Setup, packaging and launch scripts
/models            # Placeholder for additional GGUF models
/configs           # Desktop and service configuration files
```

## Build the base image

```bash
docker build -f docker/base.Dockerfile -t offline-llm/base:1.0 .
```

## Seed the Qwen3-32B model volume

Place `Qwen3-32B-*.gguf` files in the repository root and run:

```bash
docker build -f docker/model.Dockerfile -t qwen3-model:1.0 .
docker volume create qwen3-model
docker run --rm -v qwen3-model:/models/qwen3-32b qwen3-model:1.0
```

## Launch
- No host Python or pip required. All dependencies are installed inside Docker images. You won’t hit PEP 668 errors.

Copy `.env.example` to `.env` and set `WEBUI_SECRET`. Adjust `PREVIEW_SERVICE_URL` if the preview service runs elsewhere; the default `DATABASE_URL` already points to the persistent SQLite database.

Install the desktop shortcut (optional):

```bash
chmod +x scripts/install_shortcut.sh
./scripts/install_shortcut.sh
```

Start the stack:

```bash
./scripts/launch.sh
```

Open WebUI is available at [http://localhost:8080](http://localhost:8080) or via the **Offline LLM Assistant** launcher.

### Register the preview service

1. Open WebUI and sign in.
2. Navigate to **Settings → User → Tool Servers**.
3. Click **Add** and set:
   - **Name:** `PDF Preview Service`
   - **OpenAPI URL:** `http://preview-service:5001/openapi.json`
4. Save. The preview-service will now handle document uploads and knowledge ingestion.

The preview-service image bundles Tika, OCR, and PDF libraries so it works fully offline with no runtime downloads.

To keep the stack running in the background after login, enable the user service installed by `install_shortcut.sh`:

```bash
systemctl --user enable --now offline-llm.service
```

Ensure your `~/.bashrc` contains `unset DOCKER_HOST` so the service uses the default socket.

## Multi‑model support

Additional GGUF models can be added to the `models/` directory.  Inside the running Ollama container, use `ollama run /models/<model>.gguf` to load them alongside Qwen3-32B.

## Persistent chat history

Open WebUI stores conversation data in a SQLite database located at `./data/webui/sqlite.db` on the host, mounted as `/app/backend/data/sqlite.db` inside the container.  To back up your chat history, stop the stack and copy this file:

```bash
docker compose down
cp data/webui/sqlite.db /path/to/backup/
```

Restoring is as simple as copying the file back to `data/webui/` before starting the containers again.

## Git helper

Add an alias that syncs a branch with `origin/main`:

```bash
git config --global alias.sync '!f() { git fetch origin && git switch "$1" && git rebase origin/main && git push origin "$1"; }; f'
```

Use it as `git sync feature-branch` or run the helper script:

```bash
scripts/git-sync.sh feature-branch
```

## Packaging

Create a self-contained archive of the stack and required images:

```bash
scripts/package_offline_assistant.sh
```

## Update

Refresh system packages, GPU drivers, Docker and images, then restart the stack:

```bash
scripts/update_offline_assistant.sh
```
