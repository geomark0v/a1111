#!/bin/bash
set -e

echo "[INFO] Downloading all models into /runpod-volume..."
python3 /workspace/download_models.py

echo "[INFO] Starting Forge..."
exec python3 /workspace/stable-diffusion-webui-forge/launch.py \
     --listen \
     --port 8080 \
     --api \
     --skip-torch-cuda-test \
     --no-half-vae \
     --opt-sdp-no-mem-attention \
     --xformers
