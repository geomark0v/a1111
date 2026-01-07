#!/bin/bash
set -e

# Network Volume
BASE=/runpod-volume

echo "[INFO] Ensuring folders..."
mkdir -p $BASE/models
mkdir -p $BASE/extensions

echo "[INFO] Cloning Forge and extensions (runtime)..."
if [ ! -d $BASE/stable-diffusion-webui-forge ]; then
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git $BASE/stable-diffusion-webui-forge
fi

if [ ! -d $BASE/extensions/sd-webui-controlnet ]; then
    git clone https://github.com/Mikubill/sd-webui-controlnet $BASE/extensions/sd-webui-controlnet
fi

if [ ! -d $BASE/extensions/sd-webui-reactor ]; then
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git $BASE/extensions/sd-webui-reactor
fi

if [ ! -d $BASE/extensions/adetailer ]; then
    git clone https://github.com/Bing-su/adetailer $BASE/extensions/adetailer
fi

# Скачиваем модели в /runpod-volume (runtime)
echo "[INFO] Downloading models..."
python3 /workspace/download_models.py

# Запуск Forge
echo "[INFO] Starting Forge..."
exec python3 $BASE/stable-diffusion-webui-forge/launch.py \
     --listen \
     --port 8080 \
     --api \
     --skip-torch-cuda-test \
     --no-half-vae \
     --opt-sdp-no-mem-attention \
     --xformers
