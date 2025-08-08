# docker/preview_service.Dockerfile
FROM python:3.12-slim

WORKDIR /app

# system deps
RUN apt-get update && apt-get install -y \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-ces \
    libmagic1 \
    libgl1 \
    unzip \
    curl \
 && rm -rf /var/lib/apt/lists/*

# Pin requirements for stability
COPY services/preview_service/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Tika jar (used by service)
RUN mkdir -p /opt/tika && \
    curl -L https://dlcdn.apache.org/tika/2.9.1/tika-server-standard-2.9.1.jar -o /opt/tika/tika.jar

COPY services/preview_service/ .

EXPOSE 5051
HEALTHCHECK --interval=30s --timeout=5s --retries=10 CMD curl -sf http://localhost:5051/health || exit 1

CMD ["python", "app.py"]
