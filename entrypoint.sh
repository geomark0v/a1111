#!/bin/bash
set -euo pipefail

VOLUME="/runpod-volume"
BASE="$VOLUME/stable-diffusion-webui-forge"

echo "[INFO] RunPod Serverless worker started - $(date)"

# Проверка монтирования volume
if [ ! -d "$VOLUME" ]; then
    echo "[ERROR] Network Volume not mounted! Check endpoint settings."
    sleep infinity
fi

# Создание структуры
mkdir -p "$VOLUME/models/Stable-diffusion" \
         "$VOLUME/extensions" \
         "$VOLUME/logs"

# Forge
if [ ! -d "$BASE" ]; then
    echo "[INFO] Cloning Forge (first time)..."
    git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git "$BASE"
else
    echo "[INFO] Forge found in volume"
fi

# Расширения (если отсутствуют — клонируем)
extensions=(
    "sd-webui-controlnet:https://github.com/Mikubill/sd-webui-controlnet"
    "sd-webui-reactor:https://codeberg.org/Gourieff/sd-webui-reactor.git"
    "adetailer:https://github.com/Bing-su/adetailer"
)

for ext in "${extensions[@]}"; do
    name="${ext%%:*}"
    url="${ext#*:}"
    path="$BASE/extensions/$name"

    if [ ! -d "$path" ]; then
        echo "[INFO] Cloning $name..."
        git clone "$url" "$path"

        # Проверяем и выполняем install.py ТОЛЬКО после первого клонирования
        requirements="$path/requirements.txt"
        if [ -f "$requirements" ]; then
            echo "[INFO] Found install.py in $name — running it..."
            pip install -r "$requirements" || {
                echo "[WARNING] pip install --no-cache-dir -r requirements.txt in $name failed, but continuing..."
            }
        else
            echo "[SKIP] No install.py in $name"
        fi
    else
        echo "[INFO] $name already exists — skipping clone and install"
    fi
done

# Скачивание моделей (один раз или при обновлении)
echo "[INFO] Ensuring models are downloaded..."
python3 /workspace/download_models.py

# Запуск Forge
cd "$BASE"
echo "[INFO] Launching Forge WebUI with API..."

python3 launch.py \
    --listen \
    --port 8080 \
    --api \
    --skip-version-check \
    --no-download-sd-model \
    --skip-python-version-check \
    --skip-install \
    --no-hashing \
    --no-half-vae \
    --opt-sdp-no-mem-attention \
    --xformers \
    &  # ← фон!

echo "[INFO] Starting RunPod handler..."
exec python3 /workspace/handler.py