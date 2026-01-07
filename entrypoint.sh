#!/bin/bash
set -e

# 1️⃣ Скачиваем все модели на cold start
python3 /workspace/download_models.py

# 2️⃣ Старт Forge с API
python3 launch.py \
    --listen \
    --port 8080 \
    --api \
    --skip-torch-cuda-test \
    --no-half-vae \
    --opt-sdp-no-mem-attention \
    --xformers
