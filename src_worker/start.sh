#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

set -e

echo "Инициализация симлинков на persistent volume..."

# Создаём базовую папку на volume
mkdir -p /runpod-volume/models

# Список всех подпапок (точно как у тебя)
SUBDIRS=(
    "checkpoints"
    "vae"
    "unet"
    "clip"
    "loras"
    "upscale_models"
    "insightface"
    "facerestore_models"
    "facedetection"
    "nsfw_detector"
    "controlnet"
    "clip_vision"
    "codeformer"
    "adetailer"
)

for sub in "${SUBDIRS[@]}"; do
    # Создаём подпапку на volume, если её ещё нет
    mkdir -p "/workspace/comfyui/models/$sub"

    # Целевой путь симлинка
    target="/comfyui/models/$sub"

    # Если симлинк уже существует и правильный — ничего не делаем
    if [ -L "$target" ] && [ "$(readlink -f "$target")" = "/workspace/comfyui/models/$sub" ]; then
        echo "Симлинк $target уже правильный — пропускаем"
        continue
    fi

    # Создаём свежий симлинк
    ln -sfn "/workspace/comfyui/models/$sub" "$target"
    echo "Симлинк создан/обновлён: $target → /workspace/comfyui/models/$sub"
done

# Отдельная папка для ReActor (маленькая, можно оставить в /root)
mkdir -p /root/.reactor/models

echo "Все симлинки готовы!"

python /install_custom_nodes.py
# Запускаем скачивание всех моделей одним RUN
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
    python -u /comfyui/main.py python3 main.py --listen 0.0.0.0 --port 8188 &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi