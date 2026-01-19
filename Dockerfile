# Build argument for base image selection
ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

# Stage 1: Base image with common dependencies
FROM ${BASE_IMAGE} AS base

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

# Install system packages (including git and unzip for custom nodes)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv git wget curl unzip \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
    build-essential g++ gcc python3-dev python3.12-dev \
    && apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv + create venv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && ln -sf /root/.local/bin/uv /usr/local/bin/uv \
    && ln -sf /root/.local/bin/uvx /usr/local/bin/uvx \
    && uv venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

# Install comfy-cli and basic tools
RUN uv pip install --no-cache-dir comfy-cli pip setuptools wheel

# Install ComfyUI directly (stable method)
RUN git clone https://github.com/Comfy-Org/ComfyUI /comfyui \
    && cd /comfyui \
    && uv pip install --no-cache-dir -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121

# Optional PyTorch upgrade
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --no-cache-dir --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

WORKDIR /comfyui

# Add extra model paths
ADD src_worker/extra_model_paths.yaml ./

# Install runtime dependencies
RUN uv pip install --no-cache-dir runpod requests websocket-client

# Install Jupyter if enabled
RUN if [ "$JUPYTER_ENABLED" = "true" ]; then \
      uv pip install --no-cache-dir jupyterlab jupyter ipykernel; \
    fi

# Install build tools for insightface and other C++ extensions
RUN apt-get update && apt-get install -y \
    build-essential g++ gcc python3-dev python3.12-dev \
    && rm -rf /var/lib/apt/lists/*

# Install ReActor/Insightface dependencies
RUN uv pip install --no-cache-dir insightface onnxruntime-gpu fal-client xxhash

# Create persistent directories
RUN mkdir -p /workspace/comfyui/custom_nodes \
    /workspace/comfyui/models/{checkpoints,vae,unet,clip,loras,upscale_models,insightface,facerestore_models,facedetection,nsfw_detector,controlnet,clip_vision,codeformer,adetailer,ipadapter} \
    /root/.reactor/models \
    /workspace/venv

# Create persistent venv for custom nodes dependencies
RUN uv venv /workspace/venv --python python3.12

# Install all custom nodes directly in Dockerfile (on persistent volume)
RUN cd /workspace/comfyui/custom_nodes && \
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
        target_dir="/workspace/comfyui/custom_nodes/$repo_dir"; \
        if [ ! -d "$target_dir" ]; then \
            if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
                git clone --recursive "$repo" "$target_dir"; \
            else \
                git clone "$repo" "$target_dir"; \
            fi; \
        fi; \
        if [ -f "$target_dir/requirements.txt" ]; then \
            /workspace/venv/bin/pip install --no-cache-dir -r "$target_dir/requirements.txt" || echo "Failed to install requirements for $repo_dir"; \
        fi; \
        if [ -f "$target_dir/install.py" ]; then \
            /workspace/venv/bin/python "$target_dir/install.py" || echo "Failed to run install.py for $repo_dir"; \
        fi; \
        if [ "$repo_dir" = "comfyui-reactor-node" ]; then \
            echo "ReActor installed on volume"; \
            /workspace/venv/bin/python -c "import sys; sys.path.append('$target_dir'); import reactor; print('ReActor OK')" 2>/dev/null || echo "ReActor import failed"; \
        fi; \
    done && \
    # Create symlink to custom_nodes
    [ -L "/comfyui/custom_nodes" ] && rm -f "/comfyui/custom_nodes" || true && \
    [ -d "/comfyui/custom_nodes" ] && rm -rf "/comfyui/custom_nodes" || true && \
    ln -sfn /workspace/comfyui/custom_nodes /comfyui/custom_nodes

# Create symlink for models
RUN [ -L "/comfyui/models" ] && rm -f "/comfyui/models" || true && \
    [ -d "/comfyui/models" ] && rm -rf "/comfyui/models" || true && \
    ln -sfn /workspace/comfyui/models /comfyui/models

# Add application code and scripts
ADD src_worker/start.sh handler.py test_input.json download_models.py ./
RUN chmod +x /start.sh

# Add scripts
COPY scripts/comfy-node-install.sh /usr/local/bin/comfy-node-install
RUN chmod +x /usr/local/bin/comfy-node-install

COPY scripts/comfy-manager-set-mode.sh /usr/local/bin/comfy-manager-set-mode
RUN chmod +x /usr/local/bin/comfy-manager-set-mode

ENV PIP_NO_INPUT=1

# Default command
CMD ["/start.sh"]