#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

set -e
# Активируем persistent venv (сохраняет все зависимости custom nodes)
source /workspace/venv/bin/activate

# Базовая папка на volume
mkdir -p /workspace/comfyui/models

# Полный список всех подпапок (твой список)
SUBDIRS=(
    "adetailer"
    "clip"
    "configs"
    "diffusion_models"
    "facerestore_models"
    "hypernetworks"
    "latent_upscale_models"
    "nsfw_detector"
    "sams"
    "ultralytics"
    "vae"
    "audio_encoders"
    "clip_vision"
    "controlnet"
    "embeddings"
    "gligen"
    "insightface"
    "loras"
    "photomaker"
    "style_models"
    "unet"
    "vae_approx"
    "checkpoints"
    "codeformer"
    "diffusers"
    "facedetection"
    "huggingface_cache"
    "ipadapter"
    "model_patches"
    "reactor"
    "text_encoders"
    "upscale_models"
)

for sub in "${SUBDIRS[@]}"; do
    # Создаём подпапку на volume (если нет)
    mkdir -p "/workspace/comfyui/models/$sub"

    # Целевой путь симлинка
    target="/comfyui/models/$sub"

    # Если уже правильный симлинк — пропускаем
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "/workspace/comfyui/models/$sub" ]; then
        echo "Симлинк $target уже правильный — пропускаем"
        continue
    fi

    # Удаляем только если битый симлинк
    if [ -L "$target" ]; then
        rm -f "$target"
    fi

    # Создаём свежий симлинк
    ln -sfn "/workspace/comfyui/models/$sub" "$target"
    echo "Симлинк создан: $target → /workspace/comfyui/models/$sub"
done

echo "Все симлинки для папок моделей готовы!"

python /install_custom_nodes.py
# Запускаем скачивание всех моделей одним RUN
python /download_models.py

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-qwen-image-edit - Could not set ComfyUI-Manager network_mode" >&2

echo "worker-qwen-image-edit: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /workspace/comfyui/main.py --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-qwen-image-edit: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /workspace/comfyui/main.py --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-qwen-image-edit: Starting RunPod Handler"
    python -u /handler.py
fi
