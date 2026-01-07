# Базовый образ с CUDA 12.4 и Ubuntu 22.04 (оптимально для Forge + Torch 2.4)
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# Системные пакеты
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    wget git python3 python3-pip python3-venv \
    libglib2.0-0 libsm6 libgl1 libxrender1 libxext6 \
    build-essential cmake python3-dev libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# Создаём пользователя runpod (стандарт RunPod)
RUN useradd -m -s /bin/bash runpod
USER runpod
WORKDIR /workspace

# Клонируем Forge
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git stable-diffusion-webui-forge

WORKDIR /workspace/stable-diffusion-webui-forge

# Установка Torch и зависимостей
RUN pip install --no-cache-dir torch==2.4.0+cu124 torchvision==0.19.0+cu124 torchaudio==2.4.0+cu124 \
    --index-url https://download.pytorch.org/whl/cu124

RUN pip install --no-cache-dir -r requirements.txt

# Дополнительные зависимости для расширений
RUN pip install --no-cache-dir \
    runpod==1.7.6 \
    insightface==0.7.3 \
    onnxruntime-gpu \
    ultralytics

# Установка расширений
RUN mkdir -p extensions && \
    git clone https://github.com/Mikubill/sd-webui-controlnet extensions/sd-webui-controlnet && \
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum && \
    git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor

# Pony модели
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

# GFPGAN / CodeFormer (опционально, для face restore)
RUN mkdir -p models/GFPGAN models/Codeformer && \
    wget -O models/GFPGAN/GFPGANv1.4.pth "https://huggingface.co/IgorGent/pony/resolve/main/GFPGANv1.4.pth" && \
    wget -O models/Codeformer/codeformer.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer.pth" && \
    wget -O models/Codeformer/codeformer-v0.1.0.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer-v0.1.0.pth"

# Копируем наш кастомный handler
COPY rp_handler.py .

# Экспоз порта (RunPod использует 8080 для HTTP, но Serverless Queue работает через handler)
EXPOSE 8080

# Запуск Serverless handler'а
CMD ["python", "-u", "rp_handler.py"]