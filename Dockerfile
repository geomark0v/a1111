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

ENV DOWNLOAD_MODELS=false

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

# Вместо этого — прямая установка (самый стабильный способ в 2026)
RUN git clone https://github.com/Comfy-Org/ComfyUI /comfyui && \
    cd /comfyui && \
    uv pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu121

# Upgrade PyTorch if needed (for newer CUDA versions)
RUN if [ "$ENABLE_PYTORCH_UPGRADE" = "true" ]; then \
      uv pip install --force-reinstall torch torchvision torchaudio --index-url ${PYTORCH_INDEX_URL}; \
    fi

# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src_worker/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Ensure .reactor directory exists for ReActor models
RUN mkdir -p /root/.reactor/models

# Check available ComfyUI nodes after ReActor installation
RUN echo "Checking available ComfyUI nodes..."; \
    python -c "import sys; sys.path.append('/comfyui'); from comfy import model_management; print('ComfyUI imported successfully')" 2>/dev/null || echo "ComfyUI import failed"; \
    find /comfyui/custom_nodes -name "*.py" | grep -i reactor | head -5 || echo "No ReActor Python files found"; \
    find /comfyui/custom_nodes -name "*reactor*" -type d || echo "No ReActor directories found";

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

# Set the default command to run when starting the container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

ARG HUGGINGFACE_ACCESS_TOKEN
# Set default model type for Qwen Image Edit
ARG MODEL_TYPE=qwen-image-edit

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip models/loras models/upscale_models models/insightface models/facerestore_models models/facedetection models/nsfw_detector models/controlnet models/clip_vision models/codeformer models/adetailer

# Создаём симлинк на volume для моделей (самое важное для RunPod)
RUN mkdir -p /runpod-volume/models && \
    ln -sfn /runpod-volume/models /comfyui/models && \
    mkdir -p /root/.reactor/models

# Устанавливаем зависимости
RUN uv pip install --no-cache-dir huggingface_hub hf-transfer requests

RUN if [ "$DOWNLOAD_MODELS" = "true" ]; then \
      # Запускаем скачивание всех моделей одним RUN
      python /download_models.py; \
    fi

# Copy Eyes.pt file if it exists
COPY Eyes.pt /Eyes.pt

# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image in separate layers
# Part 1: UNET models (largest files)
COPY --from=downloader /comfyui/models/unet /comfyui/models/unet

# Part 2: CLIP models
COPY --from=downloader /comfyui/models/clip /comfyui/models/clip

# Part 3: VAE, LoRA, and upscale models
COPY --from=downloader /comfyui/models/vae /comfyui/models/vae
COPY --from=downloader /comfyui/models/loras /comfyui/models/loras
COPY --from=downloader /comfyui/models/upscale_models /comfyui/models/upscale_models

# Part 4: Checkpoints (if any)
COPY --from=downloader /comfyui/models/checkpoints /comfyui/models/checkpoints

# Part 5: ReActor models (from downloader stage where models are downloaded)
COPY --from=downloader /comfyui/models/insightface /comfyui/models/insightface
COPY --from=downloader /comfyui/models/facedetection /comfyui/models/facedetection
COPY --from=downloader /comfyui/models/facerestore_models /comfyui/models/facerestore_models
COPY --from=downloader /comfyui/models/nsfw_detector /comfyui/models/nsfw_detector
COPY --from=downloader /comfyui/models/clip_vision /comfyui/models/clip_vision
COPY --from=downloader /comfyui/models/ultralytics /comfyui/models/ultralytics
COPY --from=downloader /comfyui/models/huggingface_cache /comfyui/models/huggingface_cache

# Additional copies for new directories
COPY --from=downloader /comfyui/models/controlnet /comfyui/models/controlnet
COPY --from=downloader /comfyui/models/codeformer /comfyui/models/codeformer
COPY --from=downloader /comfyui/models/adetailer /comfyui/models/adetailer

# Copy Eyes.pt if it was downloaded
COPY --from=downloader /Eyes.pt /Eyes.pt