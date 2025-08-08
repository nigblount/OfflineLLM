FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

LABEL org.opencontainers.image.source="https://github.com/yourrepo/offline-llm" \
      org.opencontainers.image.description="Base image with Python3 and CUDA runtime"

RUN apt-get update && \
    apt-get install -y python3 python3-pip git curl && \
    rm -rf /var/lib/apt/lists/*


