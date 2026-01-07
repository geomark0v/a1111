FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    HF_HUB_ENABLE_HF_TRANSFER=1

RUN apt-get update && apt-get install -y git python3.10 python3-pip && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    torch==2.3.1 torchvision==0.18.1 torchaudio==2.3.1 \
    --index-url https://download.pytorch.org/whl/cu121

RUN pip install --no-cache-dir \
    huggingface_hub[hf-transfer] \
    insightface==0.7.3 onnxruntime-gpu ultralytics xformers==0.0.26.post1

WORKDIR /workspace

COPY download_models.py .
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8080
CMD ["/workspace/entrypoint.sh"]