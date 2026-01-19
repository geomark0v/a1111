# Build argument for base image selection
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

# Единственная стадия — всё в одном образе
FROM ${BASE_IMAGE}

ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY
ARG ENABLE_PYTORCH_UPGRADE=false
ARG PYTORCH_INDEX_URL

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    NUMBA_DISABLE_JIT=1 \
    NUMBA_DEBUG=0 \
    NUMBA_OPT=0 \
    CMAKE_BUILD_PARALLEL_LEVEL=8

ENV DOWNLOAD_MODELS=false
ENV JUPYTER_ENABLED=false

# Установка системных пакетов
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv git wget curl unzip \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
    build-essential g++ gcc python3-dev python3.12-dev \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Установка uv + venv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && ln -sf /root/.local/bin/uv /usr/local/bin/uv \
    && ln -sf /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

# Установка comfy-cli и базовых зависимостей
RUN uv pip install --no-cache-dir comfy-cli pip setuptools wheel

# Установка ComfyUI
RUN git clone https://github.com/Comfy-Org/ComfyUI /comfyui \
    && cd /comfyui \
    && uv pip install --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121

# Опциональное обновление torch
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --no-cache-dir --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

WORKDIR /comfyui

# Добавляем конфиг
ADD src_worker/extra_model_paths.yaml ./

# Установка runtime-зависимостей
RUN uv pip install --no-cache-dir runpod requests websocket-client

# Установка Jupyter (если включено)
RUN if [ "$JUPYTER_ENABLED" = "true" ]; then \
      uv pip install --no-cache-dir jupyterlab jupyter ipykernel; \
    fi

# Установка build-tools для insightface и других расширений
RUN apt-get update && apt-get install -y \
    build-essential g++ gcc python3-dev python3.12-dev \
    && rm -rf /var/lib/apt/lists/*

# Установка insightface и связанных
RUN uv pip install --no-cache-dir insightface onnxruntime-gpu fal-client xxhash

# Создаём папки для моделей (плейсхолдеры)
RUN mkdir -p /comfyui/models/{checkpoints,vae,unet,clip,loras,upscale_models,insightface,facerestore_models,facedetection,nsfw_detector,controlnet,clip_vision,codeformer,adetailer,ipadapter}

# Установка всех custom nodes прямо в Dockerfile
RUN cd /comfyui/custom_nodes && \
    for repo in \
        https://github.com/ltdrdata/ComfyUI-Manager.git \
        https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
        https://github.com/kijai/ComfyUI-KJNodes.git \
        https://github.com/rgthree/rgthree-comfy.git \
        https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
        https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
        https://github.com/ClownsharkBatwing/RES4LYF.git \
        https://github.com/cubiq/ComfyUI_essentials.git \
        https://github.com/chrisgoringe/cg-image-picker.git \
        https://github.com/chflame163/ComfyUI_LayerStyle.git \
        https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git \
        https://github.com/jerrywap/ComfyUI_LoadImageFromHttpURL.git \
        https://codeberg.org/Gourieff/comfyui-reactor-node.git \
        https://github.com/RikkOmsk/ComfyUI-S3-R2-Tools.git \
        https://github.com/cubiq/ComfyUI_IPAdapter_plus.git \
        https://github.com/ZHO-ZHO-ZHO/ComfyUI-InstantID.git; \
    do \
        repo_dir=$(basename "$repo" .git); \
        if [ ! -d "$repo_dir" ]; then \
            if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
                git clone --recursive "$repo" "$repo_dir"; \
            else \
                git clone "$repo" "$repo_dir"; \
            fi; \
        fi; \
        if [ -f "$repo_dir/requirements.txt" ]; then \
            uv pip install --no-cache-dir -r "$repo_dir/requirements.txt" || echo "Failed to install requirements for $repo_dir"; \
        fi; \
        if [ -f "$repo_dir/install.py" ]; then \
            /opt/venv/bin/python "$repo_dir/install.py" || echo "Failed to run install.py for $repo_dir"; \
        fi; \
        if [ "$repo_dir" = "comfyui-reactor-node" ]; then \
            echo "ReActor установлен"; \
            /opt/venv/bin/python -c "import sys; sys.path.append('/comfyui/custom_nodes/$repo_dir'); import reactor; print('ReActor OK')" 2>/dev/null || echo "ReActor import failed"; \
        fi; \
    done

# Создаём симлинк для моделей (на случай, если volume монтируется в /workspace)
RUN ln -sfn /comfyui/models /workspace/comfyui/models || true

# Добавляем код и скрипты
ADD src_worker/start.sh handler.py test_input.json download_models.py ./
RUN chmod +x /start.sh

COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

ENV PIP_NO_INPUT=1

CMD ["/start.sh"]