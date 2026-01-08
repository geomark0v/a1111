FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HUB_ENABLE_HF_TRANSFER=1

RUN apt-get update && apt-get install -y \
    # базовое
    ca-certificates \
    git \
    wget \
    curl \
    unzip \
    nano \
    \
    # сборка python пакетов
    build-essential \
    python3-dev \
    \
    # OpenCV (libGL НЕ нужен если headless)
    libglib2.0-0 \
    \
    # svglib / reportlab / cairo / pango
    libcairo2 \
    libcairo2-dev \
    libpango-1.0-0 \
    libpango1.0-dev \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    pkg-config \
    \
    # lxml / xml / xslt
    libxml2 \
    libxslt1.1 \
    \
    # прочее
    libffi-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*


RUN pip install --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    opencv-python-headless \
    fvcore \
    mediapipe \
    svglib \
    reportlab \
    lxml

RUN pip install --upgrade pip setuptools wheel

RUN pip install --no-cache-dir \
    opencv-python-headless \
    fvcore \
    mediapipe \
    pycairo \
    svglib \
    reportlab \
    lxml

RUN pip install --no-cache-dir \
    torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

RUN pip install --no-cache-dir \
    huggingface_hub[hf-transfer] \
    insightface==0.7.3 onnxruntime-gpu ultralytics xformers==0.0.26.post1


WORKDIR /workspace

COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]