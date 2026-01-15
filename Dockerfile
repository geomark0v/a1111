# base image with cuda 12.1
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# install python 3.11 and pip
ENV DEBIAN_FRONTEND=noninteractive
# Install Python 3.11 + build dependencies (insightface needs these)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    git \
    build-essential \
    cmake \
    libprotobuf-dev \
    libgl1-mesa-glx \
    libcairo2 libcairo2-dev \
    libpango-1.0-0 libpango1.0-dev libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 pkg-config \
    libxml2 libxslt1.1 libffi-dev \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

# set python3.11 as the default python
RUN ln -sf /usr/bin/python3.11 /usr/local/bin/python && \
    ln -sf /usr/bin/python3.11 /usr/local/bin/python3

# install uv
RUN pip install uv

# create venv
ENV PATH="/.venv/bin:${PATH}"
RUN uv venv --python 3.10 /.venv

# install dependencies
RUN pip install --no-cache-dir \
    torch==2.2.2+cu118 torchvision==0.17.2+cu118 torchaudio==2.2.2+cu118 \
    --index-url https://download.pytorch.org/whl/cu118

# install remaining dependencies from PyPI
COPY requirements.txt /requirements.txt
RUN uv pip install -r /requirements.txt

RUN uv pip install xformers
RUN uv pip install runpod==1.7.9
RUN uv pip install pytorch_lightning==1.7.7
RUN uv pip install torchmetrics==0.11.4 --no-deps


WORKDIR /workspace

COPY handler.py .
COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]
