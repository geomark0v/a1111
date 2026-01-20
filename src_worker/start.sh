#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"


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
    "reswapper"
)

for sub in "${SUBDIRS[@]}"; do
    source_dir="/workspace/comfyui/models/$sub"
    target="/comfyui/models/$sub"

    # Создаём подпапку на volume (если нет)
    mkdir -p "$source_dir"

    # Проверяем, что сейчас по пути target
    if [ -L "$target" ]; then
        # Это симлинк — проверяем, правильный ли
        current_target=$(readlink -f "$target")
        if [ "$current_target" = "$source_dir" ]; then
            echo "Симлинк $target уже правильный — пропускаем"
            continue
        else
            echo "Симлинк $target битый (указывает на $current_target) — удаляем"
            rm -f "$target"
        fi
    elif [ -d "$target" ]; then
        # Это обычная директория — удаляем её
        echo "Предупреждение: $target — обычная директория, удаляем..."
        rm -rf "$target"
    elif [ -e "$target" ]; then
        # Это файл или что-то другое — удаляем
        echo "Предупреждение: $target — не директория и не симлинк, удаляем..."
        rm -f "$target"
    fi

    # Создаём свежий симлинк
    ln -sfn "$source_dir" "$target"
    echo "Симлинк создан: $target → $source_dir"
done

echo "Все симлинки для папок моделей готовы!"

python /download_models.py

if [ "${JUPYTER_ENABLED:-false}" = "true" ]; then
    echo "JUPYTER_ENABLED=true → запускаем JupyterLab"

    uv pip install --no-cache-dir jupyterlab jupyter ipykernel

    # Порт по умолчанию 8888, или берём из ENV (JUPYTER_PORT)
    PORT=${JUPYTER_PORT:-8888}

    jupyter lab \
        --ip=0.0.0.0 \
        --port="$PORT" \
        --no-browser \
        --allow-root \
        --NotebookApp.token='' \
        --NotebookApp.password='' \
        --NotebookApp.base_url=/ \
        --NotebookApp.allow_origin='*' &

    echo "JupyterLab запущен на порту $PORT"

    # Даём Jupyter запуститься (чтобы порт открылся)
    sleep 5
fi

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

echo "worker-comfyui: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /comfyui/main.py --listen 0.0.0.0 --port 8188
fi