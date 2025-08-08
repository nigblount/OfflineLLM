# docker/webui.Dockerfile
FROM ghcr.io/open-webui/open-webui:ollama

# Allow online downloads ONLY during build to bake assets
ENV HF_HUB_OFFLINE=0
ENV TRANSFORMERS_OFFLINE=0

# Install sentence-transformers and bake the multilingual-e5-base embeddings into the image
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir sentence-transformers && \
    mkdir -p /app/embeddings && \
    python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('intfloat/multilingual-e5-base', cache_folder='/app/embeddings')"

# Flip to offline by default at runtime
ENV HF_HUB_OFFLINE=1
ENV TRANSFORMERS_OFFLINE=1

# Make sure Open WebUI sees the model cache where we baked it
ENV EMBEDDINGS_DIR=/app/embeddings

# Healthcheck: verify the web UI is serving on 8080 (container internal)
HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD wget -qO- http://localhost:8080/ || exit 1
