#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

set -e
# Активируем persistent venv (сохраняет все зависимости custom nodes)
source /workspace/venv/bin/activate

mkdir -p /workspace/comfyui/models/{checkpoints,vae,unet,clip,loras,upscale_models,insightface,facerestore_models,facedetection,nsfw_detector,controlnet,clip_vision,codeformer,adetailer,ipadapter}

for dir in checkpoints vae unet clip loras upscale_models insightface facerestore_models facedetection nsfw_detector controlnet clip_vision codeformer adetailer ipadapter; do
    target="/comfyui/models/$dir"
    source="/workspace/comfyui/models/$dir"

    # Удаляем только если битый симлинк
    [ -L "$target" ] && rm -f "$target"

    ln -sfn "$source" "$target"
    echo "Симлинк: $target -> $source"
done

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
