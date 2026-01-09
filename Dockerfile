FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HUB_ENABLE_HF_TRANSFER=1

# Системные зависимости
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev build-essential \
    ca-certificates git wget curl unzip nano \
    libglib2.0-0 libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 pkg-config \
    libxml2 libxslt1.1 libffi-dev ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Обновляем pip
RUN python3 -m pip install --upgrade pip  wheel

COPY requirements.txt /workspace/requirements.txt
RUN pip install --no-cache-dir -r /workspace/requirements.txt

WORKDIR /workspace

COPY handler.py .
COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]