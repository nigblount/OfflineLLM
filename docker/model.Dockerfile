FROM alpine:3.20
WORKDIR /models/qwen3-32b
# Copy any local GGUF shards for Qwen3-32B placed at repo root before build
COPY Qwen3-32B-*.gguf .
