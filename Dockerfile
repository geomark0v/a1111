FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_HUB_ENABLE_HF_TRANSFER=1

# Системные зависимости и Python
RUN apt-get update && apt-get install -y \
    git curl unzip python3.10 python3-pip \
    libglib2.0-0 libgl1 libsm6 libxrender1 libxext6 \
    build-essential cmake libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Python libs
RUN pip install --upgrade pip
RUN pip install --no-cache-dir torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121
RUN pip install --no-cache-dir huggingface_hub[hf-transfer] diffusers accelerate safetensors \
    xformers==0.0.26.post1 onnxruntime-gpu insightface==0.7.3 ultralytics opencv-python pillow

WORKDIR /workspace

# Копируем скрипты
COPY config.py /workspace/config.py
COPY download_models.py /workspace/download_models.py
COPY launch.py /workspace/launch.py
COPY entrypoint.sh /workspace/entrypoint.sh
RUN chmod +x /workspace/entrypoint.sh

EXPOSE 8080
