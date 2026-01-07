# Стабильная база с CUDA 12.1 — рекомендована для Forge в 2026
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Системные пакеты + huggingface_hub + hf-transfer для быстрого скачивания
RUN apt-get update && apt-get install -y \
    git \
    python3.10 \
    python3-pip \
    libglib2.0-0 \
    libsm6 \
    libgl1 \
    libxrender1 \
    libxext6 \
    build-essential \
    cmake \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Установка huggingface_hub и hf-transfer (ускоряет скачивание в 5–10 раз)
RUN pip install --no-cache-dir huggingface_hub[hf-transfer] hf-transfer

# Включаем hf-transfer глобально
ENV HF_HUB_ENABLE_HF_TRANSFER=1

# Пользователь runpod
RUN useradd -m -s /bin/bash runpod
USER runpod
WORKDIR /workspace

# Клонируем Forge
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git stable-diffusion-webui-forge
WORKDIR /workspace/stable-diffusion-webui-forge

# PyTorch 2.3.1 + CUDA 12.1 (стабильно)
RUN pip install --no-cache-dir \
    torch==2.3.1 \
    torchvision==0.18.1 \
    torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# Зависимости для расширений
RUN pip install --no-cache-dir \
    insightface==0.7.3 \
    onnxruntime-gpu \
    ultralytics \
    xformers==0.0.26.post1

# Установка расширений
RUN mkdir -p extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet extensions/sd-webui-controlnet && \
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum && \
    git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor

# Pony чекпоинты — чистые имена
RUN huggingface-cli download IgorGent/pony cyberrealisticPony_v141.safetensors \
    --local-dir models/Stable-diffusion \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony "cyberrealisticPony_v141 (1).safetensors" \
    --local-dir models/Stable-diffusion \
    --local-dir-use-symlinks False \
    --filename cyberrealisticPony_v141_alt.safetensors

RUN huggingface-cli download IgorGent/pony cyberrealisticPony_v150bf16.safetensors \
    --local-dir models/Stable-diffusion \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony cyberrealisticPony_v150.safetensors \
    --local-dir models/Stable-diffusion \
    --local-dir-use-symlinks False

# IP-Adapter / InstantID модели
RUN huggingface-cli download IgorGent/pony ip-adapter-faceid-plusv2_sdxl.bin \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony ip-adapter-faceid-plusv2_sdxl_lora.safetensors \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony ip-adapter-plus-face_sdxl_vit-h.safetensors \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony "ip-adapter-plus_sdxl_vit-h (1).safetensors" \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False \
    --filename ip-adapter-plus_sdxl_vit-h_alt.safetensors

RUN huggingface-cli download IgorGent/pony "ip-adapter_sdxl_vit-h (1).safetensors" \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False \
    --filename ip-adapter_sdxl_vit-h_alt.safetensors

RUN huggingface-cli download IgorGent/pony clip_h.pth \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony ip_adapter_instant_id_sdxl.bin \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony control_instant_id_sdxl.safetensors \
    --local-dir extensions/sd-webui-controlnet/models \
    --local-dir-use-symlinks False

# ReActor ONNX модели
RUN huggingface-cli download IgorGent/pony inswapper_128.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony 1k3d68.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony 2d106det.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony genderage.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony glintr100.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony scrfd_10g_bnkps.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony det_10g.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony w600k_r50.onnx \
    --local-dir extensions/sd-webui-reactor/models \
    --local-dir-use-symlinks False

# GFPGAN / CodeFormer
RUN huggingface-cli download IgorGent/pony GFPGANv1.4.pth \
    --local-dir models/GFPGAN \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony codeformer.pth \
    --local-dir models/Codeformer \
    --local-dir-use-symlinks False

RUN huggingface-cli download IgorGent/pony codeformer-v0.1.0.pth \
    --local-dir models/Codeformer \
    --local-dir-use-symlinks False

# Запуск Forge с API
EXPOSE 8080

CMD ["python", "launch.py", \
     "--listen", \
     "--port", "8080", \
     "--api", \
     "--skip-torch-cuda-test", \
     "--no-half-vae", \
     "--opt-sdp-no-mem-attention", \
     "--xformers"]