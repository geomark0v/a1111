FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HUB_ENABLE_HF_TRANSFER=1

# ----------------------------
# 1. Системные пакеты (полный набор для всех расширений)
# ----------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 python3-pip python3-dev build-essential \
    ca-certificates git wget curl unzip nano \
    libglib2.0-0 libgl1-mesa-glx libsm6 libxrender1 libxext6 \
    libcairo2 libcairo2-dev libpango-1.0-0 libpango1.0-dev libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 pkg-config \
    libxml2 libxslt1.1 libffi-dev \
    ffmpeg libopencv-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Создаём symlink python → python3.10 (чтобы subprocess.Popen(["python", ...]) работал)
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# ----------------------------
# 2. Обновляем pip
# ----------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel

# ----------------------------
# 3. Pycairo + svglib (для ControlNet reference preprocessor)
# ----------------------------
RUN pip install --no-cache-dir pycairo
RUN pip install --no-cache-dir svglib reportlab lxml

# ----------------------------
# 4. OpenCV + fvcore + mediapipe (для ADetailer, ReActor)
# ----------------------------
RUN pip install --no-cache-dir opencv-python-headless fvcore
RUN pip install --no-cache-dir mediapipe

# ----------------------------
# 5. Torch + CUDA 12.1 (стабильно для Forge)
# ----------------------------
RUN pip install --no-cache-dir \
    torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# ----------------------------
# 6. Основные пакеты для Forge и расширений
# ----------------------------
# Основные пакеты (без xformers и insightface сначала)
RUN pip install --no-cache-dir \
    huggingface_hub[hf-transfer] \
    transformers \
    sentencepiece \
    ultralytics \
    opencv-python-headless \
    pillow

# onnxruntime-gpu (рекомендуемая версия для CUDA 12.1)
RUN pip install --no-cache-dir onnxruntime-gpu==1.18.0

# insightface (после onnxruntime)
RUN pip install --no-cache-dir insightface==0.7.3

# xformers — совместимая версия для PyTorch 2.3.1 + cu121
RUN pip install --no-cache-dir xformers==0.0.25.post1  # или 0.0.26 если работает, но 0.0.25 стабильнее

# ----------------------------
# 7. RunPod SDK (для handler'а, если используешь)
# ----------------------------
RUN pip install --no-cache-dir runpod==1.7.0

# ----------------------------
# 8. Дополнительные пакеты (часто нужны в 2026 для расширений)
# ----------------------------
RUN pip install --no-cache-dir \
    bitsandbytes \
    safetensors \
    pillow \
    numpy \
    scipy \
    tqdm \
    psutil \
    gradio==4.44.0 \                 # Forge использует Gradio 4.x \
    fastapi uvicorn                  # для API (Forge их использует)

WORKDIR /workspace

COPY handler.py .
COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]
