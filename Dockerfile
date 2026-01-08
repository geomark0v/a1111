FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HUB_ENABLE_HF_TRANSFER=1

# ----------------------------
# 1. Системные зависимости
# ----------------------------
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev build-essential \
    ca-certificates git wget curl unzip nano \
    libglib2.0-0 libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 pkg-config \
    libxml2 libxslt1.1 libffi-dev ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# 2. Обновляем pip
# ----------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel

# ----------------------------
# 3. Pycairo + svglib
# ----------------------------
RUN pip install --no-cache-dir pycairo
RUN pip install --no-cache-dir svglib reportlab lxml

# ----------------------------
# 4. OpenCV + fvcore + mediapipe
# ----------------------------
RUN pip install --no-cache-dir opencv-python-headless fvcore
RUN pip install --no-cache-dir mediapipe
RUN pip install --no-cache-dir sentencepiece
RUN pip install --no-cache-dir bitsandbytes
RUN pip install --no-cache-dir pillow
RUN pip install --no-cache-dir uvicorn
RUN pip install --no-cache-dir scipy
RUN pip install --no-cache-dir lightning
RUN pip install --no-cache-dir setuptools==69.5.1
RUN pip install --no-cache-dir GitPython==3.1.32
RUN pip install --no-cache-dir Pillow==9.5.0
RUN pip install --no-cache-dir accelerate==0.31.0
RUN pip install --no-cache-dir blendmodes==2022
RUN pip install --no-cache-dir clean-fid==0.1.35
RUN pip install --no-cache-dir diskcache==5.6.3
RUN pip install --no-cache-dir einops==0.4.1
RUN pip install --no-cache-dir facexlib==0.3.0
RUN pip install --no-cache-dir fastapi==0.104.1
RUN pip install --no-cache-dir gradio==4.40.0
RUN pip install --no-cache-dir httpcore==0.15
RUN pip install --no-cache-dir inflection==0.5.1
RUN pip install --no-cache-dir jsonmerge==1.8.0
RUN pip install --no-cache-dir kornia==0.6.7
RUN pip install --no-cache-dir lark==1.1.2
RUN pip install --no-cache-dir numpy==1.26.2
RUN pip install --no-cache-dir omegaconf==2.2.3
RUN pip install --no-cache-dir open-clip-torch==2.20.0
RUN pip install --no-cache-dir piexif==1.1.3
RUN pip install --no-cache-dir protobuf==3.20.0
RUN pip install --no-cache-dir psutil==5.9.5
RUN pip install --no-cache-dir pytorch_lightning==1.9.4
RUN pip install --no-cache-dir resize-right==0.0.2
RUN pip install --no-cache-dir safetensors==0.4.2
RUN pip install --no-cache-dir scikit-image==0.21.0
RUN pip install --no-cache-dir spandrel==0.3.4
RUN pip install --no-cache-dir spandrel-extra-arches==0.1.1
RUN pip install --no-cache-dir tomesd==0.1.3
RUN pip install --no-cache-dir torchdiffeq==0.2.3
RUN pip install --no-cache-dir torchsde==0.2.6
RUN pip install --no-cache-dir transformers==4.46.1
RUN pip install --no-cache-dir httpx==0.24.1
RUN pip install --no-cache-dir pillow-avif-plugin==1.4.3
RUN pip install --no-cache-dir diffusers==0.31.0
RUN pip install --no-cache-dir gradio_rangeslider==0.0.6
RUN pip install --no-cache-dir gradio_imageslider==0.0.20
RUN pip install --no-cache-dir loadimg==0.1.2
RUN pip install --no-cache-dir tqdm==4.66.1
RUN pip install --no-cache-dir peft==0.13.2
RUN pip install --no-cache-dir pydantic==2.8.2
RUN pip install --no-cache-dir huggingface-hub==0.26.2
RUN pip install --no-cache-dir numpy scikit-image

# ----------------------------
# 5. Torch + CUDA 12.1
# ----------------------------
RUN pip install --no-cache-dir \
    torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# ----------------------------
# 6. HuggingFace + xformers + остальное
# ----------------------------
RUN pip install --no-cache-dir insightface==0.7.3 onnxruntime-gpu ultralytics xformers==0.0.26.post1
RUN pip install --no-cache-dir runpod==1.7.0  # актуальная версия на 2026 год
# ----------------------------
# 7. Рабочая директория
# ----------------------------
WORKDIR /workspace

COPY handler.py .
COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]