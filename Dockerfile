# Стабильная база с CUDA 12.1 — официально рекомендована для Forge в 2026 году
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Отключаем интерактивные вопросы
ENV DEBIAN_FRONTEND=noninteractive

# Системные пакеты
RUN apt-get update && apt-get install -y \
    wget \
    git \
    python3.10 \
    python3.10-venv \
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

# Установка стабильного PyTorch 2.3.1 + CUDA 12.1
RUN pip install --no-cache-dir \
    torch==2.3.1 \
    torchvision==0.18.1 \
    torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# Дополнительные пакеты для расширений (insightface, onnxruntime, ultralytics, xformers)
RUN pip install --no-cache-dir \
    insightface==0.7.3 \
    onnxruntime-gpu \
    ultralytics \
    xformers==0.0.26.post1  # стабильная под cu121

# Установка расширений
RUN mkdir -p extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet extensions/sd-webui-controlnet && \
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum && \
    git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor

# Pony чекпоинты
RUN mkdir -p models/Stable-diffusion && \
    cd models/Stable-diffusion && \
    wget -O cyberrealisticPony_v141.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141.safetensors" && \
    wget -O cyberrealisticPony_v141_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141%20(1).safetensors" && \
    wget -O cyberrealisticPony_v150bf16.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150bf16.safetensors" && \
    wget -O cyberrealisticPony_v150.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150.safetensors"

# IP-Adapter / InstantID модели
RUN mkdir -p extensions/sd-webui-controlnet/models && \
    cd extensions/sd-webui-controlnet/models && \
    wget -O ip-adapter-faceid-plusv2_sdxl.bin "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin" && \
    wget -O ip-adapter-faceid-plusv2_sdxl_lora.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" && \
    wget -O ip-adapter-plus-face_sdxl_vit-h.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-plus-face_sdxl_vit-h.safetensors" && \
    wget -O ip-adapter-plus_sdxl_vit-h_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-plus_sdxl_vit-h%20(1).safetensors" && \
    wget -O ip-adapter_sdxl_vit-h_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter_sdxl_vit-h%20(1).safetensors" && \
    wget -O clip_h.pth "https://huggingface.co/IgorGent/pony/resolve/main/clip_h.pth" && \
    wget -O ip_adapter_instant_id_sdxl.bin "https://huggingface.co/IgorGent/pony/resolve/main/ip_adapter_instant_id_sdxl.bin" && \
    wget -O control_instant_id_sdxl.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/control_instant_id_sdxl.safetensors"

# ReActor ONNX модели
RUN mkdir -p extensions/sd-webui-reactor/models && \
    cd extensions/sd-webui-reactor/models && \
    wget -O inswapper_128.onnx "https://huggingface.co/IgorGent/pony/resolve/main/inswapper_128.onnx" && \
    wget -O 1k3d68.onnx "https://huggingface.co/IgorGent/pony/resolve/main/1k3d68.onnx" && \
    wget -O 2d106det.onnx "https://huggingface.co/IgorGent/pony/resolve/main/2d106det.onnx" && \
    wget -O genderage.onnx "https://huggingface.co/IgorGent/pony/resolve/main/genderage.onnx" && \
    wget -O glintr100.onnx "https://huggingface.co/IgorGent/pony/resolve/main/glintr100.onnx" && \
    wget -O scrfd_10g_bnkps.onnx "https://huggingface.co/IgorGent/pony/resolve/main/scrfd_10g_bnkps.onnx" && \
    wget -O det_10g.onnx "https://huggingface.co/IgorGent/pony/resolve/main/det_10g.onnx" && \
    wget -O w600k_r50.onnx "https://huggingface.co/IgorGent/pony/resolve/main/w600k_r50.onnx"

# GFPGAN / CodeFormer
RUN mkdir -p models/GFPGAN models/Codeformer && \
    cd models/GFPGAN && \
    wget -O GFPGANv1.4.pth "https://huggingface.co/IgorGent/pony/resolve/main/GFPGANv1.4.pth" && \
    cd ../Codeformer && \
    wget -O codeformer.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer.pth" && \
    wget -O codeformer-v0.1.0.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer-v0.1.0.pth"

# Открываем порт и запускаем Forge
EXPOSE 8080

CMD ["python", "launch.py", \
     "--listen", \
     "--port", "8080", \
     "--api", \
     "--skip-torch-cuda-test", \
     "--no-half-vae", \
     "--opt-sdp-no-mem-attention", \
     "--xformers"]