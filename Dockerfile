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
RUN pip install --no-cache-dir sentencepiece transformers
RUN pip install --no-cache-dir ultralytics
RUN pip install --no-cache-dir pillow


# ----------------------------
# 5. Torch + CUDA 12.1
# ----------------------------
RUN pip install --no-cache-dir \
    torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# ----------------------------
# 6. HuggingFace + xformers + остальное
# ----------------------------
RUN pip install --no-cache-dir huggingface_hub[hf-transfer]
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