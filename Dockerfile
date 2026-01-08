FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HUB_ENABLE_HF_TRANSFER=1

# ----------------------------
# 1. Системные зависимости
# ----------------------------
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    ca-certificates \
    git \
    wget \
    curl \
    unzip \
    nano \
    libglib2.0-0 \
    libcairo2 \
    libcairo2-dev \
    libpango-1.0-0 \
    libpango1.0-dev \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    pkg-config \
    libxml2 \
    libxslt1.1 \
    libffi-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# 2. Обновление pip и установка Python-зависимостей
# ----------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel

# Ставим pycairo через бинарный wheel, чтобы svglib не падал
RUN pip install --no-cache-dir pycairo --only-binary :all:

# Основные зависимости Forge + ControlNet
RUN pip install --no-cache-dir \
    opencv-python-headless \
    fvcore \
    mediapipe \
    svglib \
    reportlab \
    lxml \
    torch==2.3.1 \
    torchvision==0.18.1 \
    torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121 \
    huggingface_hub[hf-transfer] \
    insightface==0.7.3 \
    onnxruntime-gpu \
    ultralytics \
    xformers==0.0.26.post1

# ----------------------------
# 3. Настройка рабочего каталога
# ----------------------------
WORKDIR /workspace

COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]
