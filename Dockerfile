FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies (you already have most, but ensure compilers are there)
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev build-essential \
    ca-certificates git wget curl unzip nano \
    libglib2.0-0 libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 pkg-config \
    libxml2 libxslt1.1 libffi-dev ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip & wheel early
RUN python3 -m pip install --upgrade pip wheel setuptools

# Install torch first (good practice)
RUN pip install --no-cache-dir \
    torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

# Install critical dependencies with constraints FIRST (helps insightface build)
RUN pip install --no-cache-dir \
    onnx==1.16.1 \
    protobuf>=3.20.2,<4.0.0 \
    Cython

# Now install onnxruntime-gpu from Microsoft index
RUN pip install --no-cache-dir onnxruntime-gpu \
    --extra-index-url https://aiinfra.pkgs.visualstudio.com/PublicPackages/_packaging/onnxruntime-cuda-12/pypi/simple/

COPY requirements.txt /workspace/requirements.txt

RUN pip install --no-cache-dir insightface==0.7.3 --no-deps --verbose || true
RUN pip install --no-cache-dir -r /workspace/requirements.txt --verbose

# RunPod SDK
RUN pip install --no-cache-dir runpod==1.7.0

WORKDIR /workspace

COPY handler.py .
COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]