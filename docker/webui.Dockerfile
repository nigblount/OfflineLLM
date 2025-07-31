FROM ghcr.io/open-webui/open-webui:ollama

ENV SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1 \
    SENTENCE_TRANSFORMERS_HOME=/app/embeddings \
    EMBEDDING_MODEL=intfloat/multilingual-e5-base

# Install sentence-transformers and preload embedding model
RUN pip install --no-cache-dir sentence-transformers \
    && mkdir -p /app/embeddings \
    && python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('intfloat/multilingual-e5-base', cache_folder='/app/embeddings')"

COPY docker/webui-entrypoint.sh /usr/local/bin/webui-entrypoint.sh
RUN chmod +x /usr/local/bin/webui-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/webui-entrypoint.sh"]
CMD ["bash","start.sh"]