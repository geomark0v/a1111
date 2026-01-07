# Стабильная база с CUDA 12.1 — рекомендована для Forge
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# Системные пакеты
RUN apt-get update && apt-get install -y \
    wget \
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

# Пользователь runpod
RUN useradd -m -s /bin/bash runpod
USER runpod
WORKDIR /workspace

# Клонируем Forge
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git stable-diffusion-webui-forge
WORKDIR /workspace/stable-diffusion-webui-forge

# PyTorch 2.3.1 + CUDA 12.1
RUN pip install --no-cache-dir \
    torch==2.3.1 \
    torchvision==0.18.1 \
    torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# Пакеты для расширений
RUN pip install --no-cache-dir \
    insightface==0.7.3 \
    onnxruntime-gpu \
    ultralytics \
    xformers==0.0.26.post1

# Расширения
RUN mkdir -p extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet extensions/sd-webui-controlnet && \
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum && \
    git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor

# Создаём папки
RUN mkdir -p models/Stable-diffusion
RUN mkdir -p extensions/sd-webui-controlnet/models
RUN mkdir -p extensions/sd-webui-reactor/models
RUN mkdir -p models/GFPGAN models/Codeformer

# Pony чекпоинты — чистые имена без (1), с ретраями и таймаутами
RUN cd models/Stable-diffusion && \
    wget --tries=20 --timeout=300 --continue -O cyberrealisticPony_v141.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141.safetensors"

RUN cd models/Stable-diffusion && \
    wget --tries=20 --timeout=300 --continue -O cyberrealisticPony_v141_alt.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141%20(1).safetensors"

RUN cd models/Stable-diffusion && \
    wget --tries=20 --timeout=300 --continue -O cyberrealisticPony_v150bf16.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150bf16.safetensors"

RUN cd models/Stable-diffusion && \
    wget --tries=20 --timeout=300 --continue -O cyberrealisticPony_v150.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150.safetensors"

# IP-Adapter / InstantID модели
RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O ip-adapter-faceid-plusv2_sdxl.bin "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O ip-adapter-faceid-plusv2_sdxl_lora.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O ip-adapter-plus-face_sdxl_vit-h.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-plus-face_sdxl_vit-h.safetensors"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O ip-adapter-plus_sdxl_vit-h_alt.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-plus_sdxl_vit-h%20(1).safetensors"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O ip-adapter_sdxl_vit-h_alt.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter_sdxl_vit-h%20(1).safetensors"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O clip_h.pth "https://huggingface.co/IgorGent/pony/resolve/main/clip_h.pth"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O ip_adapter_instant_id_sdxl.bin "https://huggingface.co/IgorGent/pony/resolve/main/ip_adapter_instant_id_sdxl.bin"

RUN cd extensions/sd-webui-controlnet/models && \
    wget --tries=20 --timeout=300 --continue -O control_instant_id_sdxl.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/control_instant_id_sdxl.safetensors"

# ReActor ONNX модели
RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O inswapper_128.onnx "https://huggingface.co/IgorGent/pony/resolve/main/inswapper_128.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O 1k3d68.onnx "https://huggingface.co/IgorGent/pony/resolve/main/1k3d68.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O 2d106det.onnx "https://huggingface.co/IgorGent/pony/resolve/main/2d106det.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O genderage.onnx "https://huggingface.co/IgorGent/pony/resolve/main/genderage.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O glintr100.onnx "https://huggingface.co/IgorGent/pony/resolve/main/glintr100.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O scrfd_10g_bnkps.onnx "https://huggingface.co/IgorGent/pony/resolve/main/scrfd_10g_bnkps.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O det_10g.onnx "https://huggingface.co/IgorGent/pony/resolve/main/det_10g.onnx"

RUN cd extensions/sd-webui-reactor/models && \
    wget --tries=20 --timeout=300 --continue -O w600k_r50.onnx "https://huggingface.co/IgorGent/pony/resolve/main/w600k_r50.onnx"

# GFPGAN / CodeFormer
RUN cd models/GFPGAN && \
    wget --tries=20 --timeout=300 --continue -O GFPGANv1.4.pth "https://huggingface.co/IgorGent/pony/resolve/main/GFPGANv1.4.pth"

RUN cd models/Codeformer && \
    wget --tries=20 --timeout=300 --continue -O codeformer.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer.pth"

RUN cd models/Codeformer && \
    wget --tries=20 --timeout=300 --continue -O codeformer-v0.1.0.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer-v0.1.0.pth"

# Запуск
EXPOSE 8080

CMD ["python", "launch.py", \
     "--listen", \
     "--port", "8080", \
     "--api", \
     "--skip-torch-cuda-test", \
     "--no-half-vae", \
     "--opt-sdp-no-mem-attention", \
     "--xformers"]