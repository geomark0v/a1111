#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# =============================================================================
# Оптимизация Cold Start для RunPod Serverless
# =============================================================================

# Включаем ускоренное скачивание с HuggingFace (5-10x быстрее)
export HF_HUB_ENABLE_HF_TRANSFER=1
export HF_HOME=/tmp/hf_cache

# Базовая папка на Network Volume
VOLUME_MODELS_DIR="/workspace/comfyui/models"
COMFY_MODELS_DIR="/comfyui/models"

# Список подпапок моделей
SUBDIRS=(
    "checkpoints" "clip" "clip_vision" "controlnet" "embeddings"
    "loras" "unet" "vae" "upscale_models" "insightface" "ipadapter"
    "facerestore_models" "facedetection" "codeformer" "sams"
    "ultralytics" "nsfw_detector" "reswapper" "huggingface_cache"
)

# Создаём симлинки на Network Volume (если volume примонтирован)
if [ -d "/workspace" ]; then
    echo "worker-comfyui: Network Volume обнаружен, настраиваем симлинки..."
    mkdir -p "$VOLUME_MODELS_DIR"
    
    for sub in "${SUBDIRS[@]}"; do
        source_dir="$VOLUME_MODELS_DIR/$sub"
        target="$COMFY_MODELS_DIR/$sub"
        
        mkdir -p "$source_dir"
        
        # Удаляем существующую папку/симлинк и создаём новый
        rm -rf "$target" 2>/dev/null
        ln -sfn "$source_dir" "$target"
    done
    echo "worker-comfyui: Симлинки готовы"
    
    # Проверяем, есть ли модели на volume (проверяем один ключевой файл)
    if [ ! -f "$VOLUME_MODELS_DIR/checkpoints/cyberrealisticPony_v141.safetensors" ]; then
        echo "worker-comfyui: Модели не найдены, запускаем скачивание..."
        python /download_models.py
        echo "worker-comfyui: Скачивание завершено"
    else
        echo "worker-comfyui: Модели уже на Network Volume, пропускаем скачивание"
    fi
    
    # Копируем Eyes.pt если есть
    if [ -f "/Eyes.pt" ] && [ ! -f "$VOLUME_MODELS_DIR/Eyes.pt" ]; then
        cp /Eyes.pt "$VOLUME_MODELS_DIR/Eyes.pt"
    fi
else
    echo "worker-comfyui: Network Volume не примонтирован, используем локальные модели"
fi

# =============================================================================

# Ensure ComfyUI-Manager runs in offline network mode inside the container
comfy-manager-set-mode offline || echo "worker-comfyui - Could not set ComfyUI-Manager network_mode" >&2

echo "worker-comfyui: Starting ComfyUI"

# Allow operators to tweak verbosity; default is DEBUG.
: "${COMFY_LOG_LEVEL:=DEBUG}"

# =============================================================================
# Оптимизация запуска ComfyUI для быстрого cold start
# =============================================================================

# Отключаем лишние проверки и импорты для ускорения
export PYTORCH_CUDA_ALLOC_CONF="expandable_segments:True"
export CUDA_MODULE_LOADING=LAZY
export TRANSFORMERS_OFFLINE=1
export HF_HUB_OFFLINE=1

# Serve the API and don't shutdown the container
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    python -u /comfyui/main.py --listen 0.0.0.0 --port 8188
else
    # Запускаем ComfyUI с оптимизациями:
    # --quick-test-for-ci: пропускает некоторые проверки
    # --disable-auto-launch: не открывать браузер
    # --disable-metadata: не сохранять метаданные в изображения
    # --fast: включает быстрый режим (torch.compile и др.)
    python -u /comfyui/main.py \
        --listen 0.0.0.0 \
        --port 8188 \
        --disable-auto-launch \
        --disable-metadata \
        --dont-print-server \
        --preview-method none \
        --log-stdout &
    
    COMFY_PID=$!
    
    # Ждём готовности ComfyUI (макс 30 сек)
    echo "worker-comfyui: Ожидание запуска ComfyUI..."
    for i in {1..30}; do
        if curl -s http://127.0.0.1:8188/system_stats > /dev/null 2>&1; then
            echo "worker-comfyui: ComfyUI готов за ${i} сек"
            break
        fi
        sleep 1
    done

    echo "worker-comfyui: Starting RunPod Handler"
    python -u /handler.py --rp_serve_api --rp_api_host=0.0.0.0
fi