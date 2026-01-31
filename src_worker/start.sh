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

# =============================================================================
# Универсальная настройка для Serverless и обычных подов
# Serverless: данные в /runpod-volume
# Обычный под: данные в /workspace
# Создаём симлинк /workspace -> /runpod-volume если нужно
# =============================================================================

# Если /runpod-volume существует (Serverless), но /workspace нет - создаём симлинк
if [ -d "/runpod-volume" ] && [ ! -d "/workspace" ]; then
    echo "worker-comfyui: Serverless режим - создаём симлинк /workspace -> /runpod-volume"
    ln -sfn /runpod-volume /workspace
fi

# Если ни /runpod-volume ни /workspace не существуют - создаём /workspace
if [ ! -d "/workspace" ]; then
    echo "worker-comfyui: Создаём локальную папку /workspace"
    mkdir -p /workspace
fi

# Базовая папка на Network Volume (теперь всегда /workspace)
VOLUME_MODELS_DIR="/workspace/comfyui/models"
COMFY_MODELS_DIR="/comfyui/models"

# Список подпапок моделей
SUBDIRS=(
    "checkpoints" "clip" "clip_vision" "controlnet" "embeddings"
    "loras" "unet" "vae" "upscale_models" "insightface" "ipadapter"
    "facerestore_models" "facedetection" "codeformer" "sams"
    "ultralytics" "nsfw_detector" "reswapper" "huggingface_cache"
)

# Создаём симлинки на Network Volume
echo "worker-comfyui: Настраиваем симлинки моделей..."
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

# =============================================================================
# Режим запуска: SERVE_API_LOCALLY=true для обычного пода, иначе serverless
# =============================================================================

# Запускаем ComfyUI с оптимизациями:
# --disable-auto-launch: не открывать браузер
# --disable-metadata: не сохранять метаданные в изображения
if [ "$SERVE_API_LOCALLY" == "true" ]; then
    # Режим обычного пода - ComfyUI как основной процесс (foreground)
    echo "worker-comfyui: Запуск в режиме обычного пода (ComfyUI UI доступен на :8188)"
    exec python -u /comfyui/main.py \
        --listen 0.0.0.0 \
        --port 8188
else
    # Режим serverless - ComfyUI в фоне, handler как основной процесс
    echo "worker-comfyui: Запуск в режиме serverless"
    
    # Отключаем сетевые запросы ComfyUI-Manager
    export COMFY_MANAGER_SKIP_UPDATE=true
    export CM_NETWORK_MODE=offline
    
    python -u /comfyui/main.py \
        --listen 0.0.0.0 \
        --port 8188 \
        --disable-auto-launch \
        --disable-metadata \
        --preview-method none &

    COMFY_PID=$!

    # Ждём готовности ComfyUI (макс 180 сек / 3 минуты для cold start)
    echo "worker-comfyui: Ожидание запуска ComfyUI (макс 180 сек)..."
    COMFY_READY=false
    for i in {1..180}; do
        # Пробуем разные варианты подключения
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://127.0.0.1:8188/ 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
            echo "worker-comfyui: ComfyUI готов за ${i} сек (HTTP $HTTP_CODE)"
            COMFY_READY=true
            break
        fi
        # Проверяем что процесс ComfyUI ещё жив
        if ! kill -0 $COMFY_PID 2>/dev/null; then
            echo "worker-comfyui: ОШИБКА - ComfyUI процесс завершился!"
            exit 1
        fi
        # Логируем каждые 10 секунд с диагностикой
        if [ $((i % 10)) -eq 0 ]; then
            echo "worker-comfyui: Проверка ${i}/180 - HTTP код: $HTTP_CODE"
        fi
        sleep 1
    done

    if [ "$COMFY_READY" = false ]; then
        echo "worker-comfyui: ОШИБКА - ComfyUI не запустился за 180 сек"
        exit 1
    fi

    echo "worker-comfyui: Starting RunPod Handler"

    # Запускаем health check для ComfyUI в фоне (пинг каждые 30 сек)
    (
        while true; do
            sleep 30
            if ! curl -s http://127.0.0.1:8188/ > /dev/null 2>&1; then
                echo "worker-comfyui: WARNING - ComfyUI не отвечает на health check!"
                # Перезапускаем ComfyUI если он умер
                if ! kill -0 $COMFY_PID 2>/dev/null; then
                    echo "worker-comfyui: Перезапуск ComfyUI..."
                    python -u /comfyui/main.py \
                        --listen \
                        --disable-auto-launch \
                        --disable-metadata \
                        --dont-print-server \
                        --preview-method none \
                        --log-stdout &
                    COMFY_PID=$!
                    sleep 10
                fi
            fi
        done
    ) &
    HEALTH_PID=$!

    # Запускаем handler и держим контейнер живым
    exec python -u /handler.py
fi