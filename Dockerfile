# Базовый образ с CUDA, Torch и Python для SD (актуальный на 2026)
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# Установка системных пакетов
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    wget git python3 python3-pip python3-venv \
    libglib2.0-0 libsm6 libgl1 libxrender1 libxext6 \
    build-essential cmake python3-dev libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Создание пользователя runpod (стандарт для RunPod)
RUN useradd -m -s /bin/bash runpod
USER runpod
WORKDIR /workspace

# Клонирование Forge
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git stable-diffusion-webui-forge

WORKDIR /workspace/stable-diffusion-webui-forge

# Установка зависимостей Forge
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124 && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir insightface==0.7.3 onnxruntime-gpu ultralytics

# Установка расширений
RUN mkdir -p extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet extensions/sd-webui-controlnet && \
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum && \
    git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor

# Скачивание Pony моделей
RUN mkdir -p models/Stable-diffusion && \
    cd models/Stable-diffusion && \
    wget -O cyberrealisticPony_v141.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141.safetensors" && \
    wget -O cyberrealisticPony_v141_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141%20(1).safetensors" && \
    wget -O cyberrealisticPony_v150bf16.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150bf16.safetensors" && \
    wget -O cyberrealisticPony_v150.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150.safetensors"

# IP-Adapter / InstantID модели для ControlNet
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

# ONNX модели для ReActor
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

# Дополнительные модели GFPGAN/Codeformer
RUN mkdir -p models/GFPGAN models/Codeformer && \
    wget -O models/GFPGAN/GFPGANv1.4.pth "https://huggingface.co/IgorGent/pony/resolve/main/GFPGANv1.4.pth" && \
    wget -O models/Codeformer/codeformer.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer.pth" && \
    wget -O models/Codeformer/codeformer-v0.1.0.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer-v0.1.0.pth"

# Экспоз порта и запуск для Serverless (Forge имеет встроенную поддержку --api)
EXPOSE 8080
CMD ["python", "launch.py", "--listen", "--port", "8080", "--api", "--skip-torch-cuda-test", "--no-half-vae", "--opt-sdp-no-mem-attention"]