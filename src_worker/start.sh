#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

python /install_custom_nodes.py
# Запускаем скачивание всех моделей одним RUN
python /download_models.py

if [ "${JUPYTER_ENABLED:-false}" = "true" ]; then
    echo "JUPYTER_ENABLED=true → запускаем JupyterLab"

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
    python -u /workspace/comfyui/main.py --disable-auto-launch --disable-metadata --listen --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
else
    python -u /workspace/comfyui/main.py --disable-auto-launch --disable-metadata --verbose "${COMFY_LOG_LEVEL}" --log-stdout &

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py
fi