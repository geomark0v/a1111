FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV HF_HUB_ENABLE_HF_TRANSFER=1

# Системные пакеты
RUN apt-get update && apt-get install -y \
    git \
    ca-certificates \
    curl \
    unzip \
    python3.10 \
    python3-pip \
    libglib2.0-0 \
    libgl1 \
    libsm6 \
    libxrender1 \
    libxext6 \
    build-essential \
    cmake \
    libopencv-dev \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Python deps
RUN pip install --upgrade pip
RUN pip install --no-cache-dir \
    torch==2.3.1 \
    torchvision==0.18.1 \
    torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

RUN pip install --no-cache-dir \
    huggingface_hub[hf-transfer] \
    diffusers \
    accelerate \
    safetensors \
    xformers==0.0.26.post1 \
    onnxruntime-gpu \
    insightface==0.7.3 \
    ultralytics \
    opencv-python \
    pillow

# Workspace
WORKDIR /workspace

# Forge + extensions (ControlNet и ReActor клонируются runtime)
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git stable-diffusion-webui-forge
RUN mkdir -p extensions
WORKDIR /workspace/stable-diffusion-webui-forge

# ADetailer
RUN git clone https://github.com/Bing-su/adetailer extensions/adetailer

# sd-face-editor / Deforum
RUN git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor
RUN git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum

# Копируем скрипты
COPY config.py /workspace/config.py
COPY download_models.py /workspace/download_models.py
COPY launch.py /workspace/launch.py
COPY entrypoint.sh /workspace/entrypoint.sh
RUN chmod +x /workspace/entrypoint.sh

# expose API port
EXPOSE 8080

# Запуск через entrypoint
ENTRYPOINT ["/workspace/entrypoint.sh"]
