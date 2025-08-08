FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y \
    poppler-utils \
    tesseract-ocr \
    tesseract-ocr-ces \
    libmagic1 \
    libgl1 \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*
COPY services/preview_service/requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
RUN mkdir -p /opt/tika && \
    curl -L https://dlcdn.apache.org/tika/2.9.1/tika-server-standard-2.9.1.jar -o /opt/tika/tika.jar
COPY services/preview_service/ .
ENV TIKA_SERVER_JAR=/opt/tika/tika.jar
EXPOSE 5001
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -f http://localhost:5001/health || exit 1
CMD ["python", "app.py"]
