# Build argument for base image selection
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

# Stage 1: Base image with common dependencies
FROM ${BASE_IMAGE} AS base

# Build arguments for this stage with sensible defaults for standalone builds
ARG COMFYUI_VERSION=latest
ARG CUDA_VERSION_FOR_COMFY
ARG ENABLE_PYTORCH_UPGRADE=false
ARG PYTORCH_INDEX_URL

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Disable Numba JIT compilation to avoid LOAD_ASSERTION_ERROR
ENV NUMBA_DISABLE_JIT=1
# Additional stability settings
ENV NUMBA_DEBUG=0
ENV NUMBA_OPT=0
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Модели скачиваются при первом запуске на Network Volume (/workspace)

ENV JUPYTER_ENABLED=false

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-venv \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv (latest) using official installer and create isolated venv
RUN wget -qO- https://astral.sh/uv/install.sh | sh \
    && ln -s /root/.local/bin/uv /usr/local/bin/uv \
    && ln -s /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

# Use the virtual environment for all subsequent commands
ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli + dependencies needed by it to install ComfyUI
RUN uv pip install comfy-cli pip setuptools wheel

# Install Python runtime dependencies for the handler
RUN uv pip install runpod requests websocket-client

RUN if [ "$JUPYTER_ENABLED" = "true" ]; then \
      uv pip install --no-cache-dir jupyterlab jupyter ipykernel; \
    fi

# Открываем порт (можно сделать динамическим)
EXPOSE 8188

# Install build tools for insightface compilation
RUN apt-get update && apt-get install -y \
    build-essential \
    g++ \
    gcc \
    python3-dev \
    python3.12-dev \
    && rm -rf /var/lib/apt/lists/*

    # Install ReActor dependencies and additional libraries
RUN uv pip install insightface onnxruntime-gpu fal-client xxhash

# Прямая установка ComfyUI (самый стабильный способ в 2026)
RUN git clone https://github.com/Comfy-Org/ComfyUI /comfyui && \
    cd /comfyui && \
    uv pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121

# Upgrade PyTorch if needed (for newer CUDA versions)
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

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
        https://github.com/ZHO-ZHO-ZHO/ComfyUI-InstantID.git \
        https://github.com/jerrywap/ComfyUI_UploadToWebhookHTTP.git \
        https://github.com/tsogzark/ComfyUI-load-image-from-url.git \
        https://github.com/asagi4/comfyui-prompt-control.git \
        https://github.com/badjeff/comfyui_lora_tag_loader.git; \
    do \
        repo_dir=$(basename "$repo" .git); \
        if [ ! -d "$repo_dir" ]; then \
            if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ] || \
               [ "$repo" = "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git" ]; then \
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
        if [ "$repo_dir" = "ComfyUI-Impact-Pack" ]; then \
            echo "Installing Impact-Pack submodules..."; \
            cd "$repo_dir" && git submodule update --init --recursive && cd ..; \
            if [ -f "$repo_dir/impact_subpack/requirements.txt" ]; then \
                uv pip install --no-cache-dir -r "$repo_dir/impact_subpack/requirements.txt" || true; \
            fi; \
        fi; \
    done

# Дополнительные зависимости для Impact-Pack (FaceDetailer, SAM и др.)
RUN uv pip install --no-cache-dir \
    segment-anything \
    ultralytics \
    scikit-image \
    piexif

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src_worker/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Ensure .reactor directory exists for ReActor models
RUN mkdir -p /root/.reactor/models

    # Set environment variables to disable Hugging Face caching
ENV HF_HOME=/comfyui/models/huggingface_cache
ENV TRANSFORMERS_CACHE=/comfyui/models/huggingface_cache
ENV HF_DATASETS_CACHE=/comfyui/models/huggingface_cache

    # Create Hugging Face cache directory
RUN mkdir -p /comfyui/models/huggingface_cache

# Add application code and scripts
ADD src_worker/start.sh handler.py test_input.json download_models.py install_custom_nodes.py ./
RUN chmod +x /start.sh

# Add script to install custom nodes
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

# Prevent pip from asking for confirmation during uninstall steps in custom nodes
ENV PIP_NO_INPUT=1

# Copy helper script to switch Manager network mode at container start
COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

# Устанавливаем ComfyUI-Manager в offline режим при сборке (экономит ~2 мин на cold start)
ENV CM_NETWORK_MODE=offline
ENV COMFYUI_MANAGER_NETWORK_MODE=offline

# Создаём конфиг в правильном пути для ComfyUI-Manager V3
RUN mkdir -p /comfyui/user/default/ComfyUI-Manager && \
    echo '[default]' > /comfyui/user/default/ComfyUI-Manager/config.ini && \
    echo 'network_mode = offline' >> /comfyui/user/default/ComfyUI-Manager/config.ini && \
    echo 'update_check = false' >> /comfyui/user/default/ComfyUI-Manager/config.ini && \
    echo 'skip_update = true' >> /comfyui/user/default/ComfyUI-Manager/config.ini

# Set the default command to run when starting the container
CMD ["/start.sh"]

# Устанавливаем зависимости для скачивания моделей (hf-transfer ускоряет в 5-10 раз)
RUN uv pip install --no-cache-dir huggingface_hub hf-transfer requests

# Copy Eyes.pt file if it exists
COPY Eyes.pt /Eyes.pt
