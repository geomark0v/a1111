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

# Включаем ускоренный режим скачивания (рекомендуется для файлов >5 ГБ)
ENV HF_HUB_ENABLE_HF_TRANSFER=1

ENV HF_TOKEN=${HUGGINGFACE_ACCESS_TOKEN}

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

# Установка инструментов для скачивания (один раз в начале стадии downloader)
RUN uv pip install --no-cache-dir "huggingface_hub[cli]" hf-transfer

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

# Install ComfyUI
#RUN if [ -n "${CUDA_VERSION_FOR_COMFY}" ]; then \
#      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --cuda-version "${CUDA_VERSION_FOR_COMFY}" --nvidia; \
#    else \
#      /usr/bin/yes | comfy --workspace /comfyui install --version "${COMFYUI_VERSION}" --nvidia; \
#    fi

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

# Install comprehensive set of custom nodes for ComfyUI
RUN for repo in \
    https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git \
    https://github.com/kijai/ComfyUI-KJNodes.git \
    https://github.com/rgthree/rgthree-comfy.git \
    # https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git \
    https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git \
    # https://github.com/Jordach/comfy-plasma.git \
    https://github.com/ltdrdata/ComfyUI-Impact-Pack.git \
    https://github.com/ClownsharkBatwing/RES4LYF.git \
    # https://github.com/yolain/ComfyUI-Easy-Use.git \
    # https://github.com/WASasquatch/was-node-suite-comfyui.git \
    # https://github.com/theUpsider/ComfyUI-Logic.git \
    https://github.com/cubiq/ComfyUI_essentials.git \
    https://github.com/chrisgoringe/cg-image-picker.git \
    https://github.com/chflame163/ComfyUI_LayerStyle.git \
    https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git \
    # https://github.com/Jonseed/ComfyUI-Detail-Daemon.git \
    # https://github.com/shadowcz007/comfyui-mixlab-nodes.git \
    # https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git \
    # https://github.com/bash-j/mikey_nodes.git \
    # https://github.com/chrisgoringe/cg-use-everywhere.git \
    # https://github.com/M1kep/CfyLiterals.gitom \
    https://github.com/jerrywap/ComfyUI_LoadImageFromHttpURL.git \
    https://github.com/Gourieff/ComfyUI-ReActor.git \
    https://github.com/RikkOmsk/ComfyUI-S3-R2-Tools.git \
    https://github.com/cubiq/ComfyUI_IPAdapter_plus.git \
    https://github.com/ZHO-ZHO-ZHO/ComfyUI-InstantID.git; \
    do \
        cd /comfyui/custom_nodes; \
        repo_dir=$(basename "$repo" .git); \
        if [ "$repo" = "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git" ]; then \
            git clone --recursive "$repo"; \
        else \
            git clone "$repo"; \
        fi; \
        if [ -f "/comfyui/custom_nodes/$repo_dir/requirements.txt" ]; then \
            pip install -r "/comfyui/custom_nodes/$repo_dir/requirements.txt"; \
        fi; \
        if [ -f "/comfyui/custom_nodes/$repo_dir/install.py" ]; then \
            python "/comfyui/custom_nodes/$repo_dir/install.py"; \
        fi; \
        if [ "$repo_dir" = "ComfyUI-ReActor" ]; then \
            echo "ReActor installed, checking for models..."; \
            mkdir -p /root/.reactor/models; \
            echo "Checking ReActor installation....."; \
            ls -la /comfyui/custom_nodes/ComfyUI-ReActor/ || echo "ReActor directory not found"; \
            find /comfyui/custom_nodes/ComfyUI-ReActor -name "*.py" | head -10 || echo "No Python files found in ReActor"; \
            find /root -name ".reactor" -type d 2>/dev/null || echo "No .reactor directory found in /root"; \
            find /comfyui -name "*reactor*" -type d 2>/dev/null || echo "No reactor directories found in /comfyui"; \
            find /comfyui -name "*face*" -type d 2>/dev/null || echo "No face directories found in /comfyui"; \
            ls -la /root/.reactor/ 2>/dev/null || echo "No files in /root/.reactor"; \
            ls -la /root/.reactor/models/ 2>/dev/null || echo "No files in /root/.reactor/models"; \
            echo "Checking if ReActor nodes are available..."; \
            python -c "import sys; sys.path.append('/comfyui/custom_nodes/ComfyUI-ReActor'); import reactor; print('ReActor module imported successfully')" 2>/dev/null || echo "ReActor module import failed"; \
        fi; \
    done

# Go back to the root
WORKDIR /

# Ensure .reactor directory exists for ReActor models
RUN mkdir -p /root/.reactor/models

# Check available ComfyUI nodes after ReActor installation
RUN echo "Checking available ComfyUI nodes..."; \
    python -c "import sys; sys.path.append('/comfyui'); from comfy import model_management; print('ComfyUI imported successfully')" 2>/dev/null || echo "ComfyUI import failed"; \
    find /comfyui/custom_nodes -name "*.py" | grep -i reactor | head -5 || echo "No ReActor Python files found"; \
    find /comfyui/custom_nodes -name "*reactor*" -type d || echo "No ReActor directories found";

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

    # Set environment variables to disable Hugging Face caching
ENV HF_HOME=/comfyui/models/huggingface_cache
ENV TRANSFORMERS_CACHE=/comfyui/models/huggingface_cache
ENV HF_DATASETS_CACHE=/comfyui/models/huggingface_cache

    # Create Hugging Face cache directory
RUN mkdir -p /comfyui/models/huggingface_cache

# Add application code and scripts
ADD src_worker/start.sh handler.py test_input.json ./
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
# CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

ARG HUGGINGFACE_ACCESS_TOKEN
# Set default model type for Qwen Image Edit
ARG MODEL_TYPE=qwen-image-edit

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip models/loras models/upscale_models models/insightface models/facerestore_models models/facedetection models/nsfw_detector models/controlnet models/clip_vision models/codeformer models/adetailer

# Download Qwen Image Edit models
RUN echo "Downloading Qwen Image Edit models..."

# Download UNET&CLIP Large model (using correct URL structure)
# RUN wget -q --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/unet/qwen_image_edit_2509_bf16.safetensors "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_bf16.safetensors"
# RUN wget -q --header="Authorization: Bearer ${HUGGINGFACE_ACCESS_TOKEN}" -O models/clip/qwen_2.5_vl_7b.safetensors "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b.safetensors"

# Download UNET&CLIP fp8 model (using correct URL structure)
RUN hf download lightx2v/Qwen-Image-Lightning \
    Qwen-Image-Edit-2509/qwen_image_edit_2509_fp8_e4m3fn_scaled.safetensors \
    --local-dir models/unet --local-dir-use-symlinks False

RUN hf download Comfy-Org/z_image_turbo \
    split_files/diffusion_models/z_image_turbo_bf16.safetensors \
    --local-dir models/unet --local-dir-use-symlinks False

RUN hf download Comfy-Org/Qwen-Image_ComfyUI \
    split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors \
    --local-dir models/clip --local-dir-use-symlinks False

RUN hf download Comfy-Org/z_image_turbo \
    split_files/text_encoders/qwen_3_4b.safetensors \
    --local-dir models/clip --local-dir-use-symlinks False

# Download VAE model (using correct URL structure)
RUN hf download Comfy-Org/Qwen-Image_ComfyUI \
    split_files/vae/qwen_image_vae.safetensors \
    --local-dir models/vae --local-dir-use-symlinks False

RUN hf download Comfy-Org/z_image_turbo \
    split_files/vae/ae.safetensors \
    --local-dir models/vae --local-dir-use-symlinks False

# Download LoRA model (public file, no auth needed)
RUN hf download lightx2v/Qwen-Image-Lightning \
    Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-8steps-V1.0-bf16.safetensors \
    --local-dir models/loras --local-dir-use-symlinks False

RUN hf download lightx2v/Qwen-Image-Lightning \
    Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors \
    --local-dir models/loras --local-dir-use-symlinks False

RUN wget -q -O models/loras/Qwen-Image-Analog-v1.1.safetensors "https://studio.swapify.link/assets/Qwen-Image-Analog-v1.1.safetensors"
RUN wget -q -O models/loras/lenovo.safetensors "https://studio.swapify.link/assets/lenovo.safetensors"

RUN hf download valiantcat/Qwen-Image-Edit-2509-photous \
    QwenEdit2509_photous_000010000.safetensors \
    --local-dir models/loras --local-dir-use-symlinks False

RUN hf download tlennon-ie/qwen-edit-skin \
    qwen-edit-skin_1.1_000002750.safetensors \
    --local-dir models/loras --local-dir-use-symlinks False

# Download upscale model (4xLSDIR.pth)
RUN hf download wavespeed/misc \
    upscalers/4xLSDIR.pth \
    --local-dir models/upscale_models --local-dir-use-symlinks False

# Download ReActor models
RUN echo "Downloading ReActor models..."
# Download inswapper model for face swapping
RUN wget -q -O models/insightface/inswapper_128.onnx "https://app.swapify.link/assets/inswapper_128.onnx"
# Download detection model for face detection
RUN wget -q -O models/facedetection/detection_Resnet50_Final.pth "https://app.swapify.link/assets/detection_Resnet50_Final.pth"
# Download GFPGAN model for face restoration
RUN wget -q -O models/facerestore_models/GFPGANv1.4.pth "https://app.swapify.link/assets/GFPGANv1.4.pth"

# Download NSFW detector models
RUN echo "Downloading NSFW detector models..."
RUN mkdir -p models/nsfw_detector/vit-base-nsfw-detector
RUN hf download AdamCodd/vit-base-nsfw-detector \
    --local-dir models/nsfw_detector/vit-base-nsfw-detector \
    --local-dir-use-symlinks False

# Download additional ReActor models
RUN echo "Downloading additional ReActor models..."
# Create insightface models directory
RUN mkdir -p models/insightface/models
# Download buffalo_l model files directly from Swapify server
RUN mkdir -p models/insightface/models/buffalo_l
RUN wget -q -O models/insightface/models/buffalo_l/1k3d68.onnx "https://app.swapify.link/assets/buffalo_l/1k3d68.onnx"
RUN wget -q -O models/insightface/models/buffalo_l/2d106det.onnx "https://app.swapify.link/assets/buffalo_l/2d106det.onnx"
RUN wget -q -O models/insightface/models/buffalo_l/det_10g.onnx "https://app.swapify.link/assets/buffalo_l/det_10g.onnx"
RUN wget -q -O models/insightface/models/buffalo_l/genderage.onnx "https://app.swapify.link/assets/buffalo_l/genderage.onnx"
RUN wget -q -O models/insightface/models/buffalo_l/w600k_r50.onnx "https://app.swapify.link/assets/buffalo_l/w600k_r50.onnx"
# Download parsing_parsenet.pth (face parsing model)
RUN wget -q -O models/facedetection/parsing_parsenet.pth "https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/parsing_parsenet.pth"

# Download YOLO models for detection and segmentation
RUN echo "Downloading YOLO models for detection and segmentation..."
RUN mkdir -p models/ultralytics/bbox models/ultralytics/segm
RUN wget -q -O models/ultralytics/bbox/face_yolov8m.pt "https://app.swapify.link/assets/face_yolov8m.pt"
RUN wget -q -O models/ultralytics/bbox/hand_yolov8s.pt "https://app.swapify.link/assets/hand_yolov8s.pt"
RUN wget -q -O models/ultralytics/segm/person_yolov8m-seg.pt "https://app.swapify.link/assets/person_yolov8m-seg.pt"

# Download additional models from the A1111 list adapted for ComfyUI
RUN echo "Downloading main generation models..."
RUN hf download IgorGent/pony \
    cyberrealisticPony_v141.safetensors \
    --local-dir models/checkpoints --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    "cyberrealisticPony_v141 (1).safetensors" \
    --local-dir models/checkpoints --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    cyberrealisticPony_v150bf16.safetensors \
    --local-dir models/checkpoints --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    cyberrealisticPony_v150.safetensors \
    --local-dir models/checkpoints --local-dir-use-symlinks False

RUN echo "Downloading ControlNet and related models..."
RUN hf download IgorGent/pony \
    ip-adapter-faceid-plusv2_sdxl.bin \
    --local-dir models/controlnet --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    ip-adapter-faceid-plusv2_sdxl_lora.safetensors \
    --local-dir models/loras --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    ip-adapter-plus-face_sdxl_vit-h.safetensors \
    --local-dir models/controlnet --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    "ip-adapter-plus_sdxl_vit-h (1).safetensors" \
    --local-dir models/controlnet --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    "ip-adapter_sdxl_vit-h (1).safetensors" \
    --local-dir models/controlnet --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    clip_h.pth \
    --local-dir models/clip_vision --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    ip_adapter_instant_id_sdxl.bin \
    --local-dir models/controlnet --local-dir-use-symlinks False

RUN hf download IgorGent/pony \
    control_instant_id_sdxl.safetensors \
    --local-dir models/controlnet --local-dir-use-symlinks False

RUN echo "Downloading insightface antelopev2 models..."
RUN mkdir -p models/insightface/models/antelopev2
RUN hf download IgorGent/pony \
    --local-dir models/insightface/models/antelopev2 \
    --local-dir-use-symlinks False \
    --include "1k3d68.onnx" \
    --include "2d106det.onnx" \
    --include "genderage.onnx" \
    --include "glintr100.onnx" \
    --include "scrfd_10g_bnkps.onnx"

RUN echo "Downloading CodeFormer and GFPGAN models..."
RUN hf download IgorGent/pony \
    --local-dir models/codeformer \
    --local-dir-use-symlinks False \
    --include "codeformer*.pth"

RUN hf download IgorGent/pony \
    --local-dir models/facedetection \
    --local-dir-use-symlinks False \
    --include "parsing_*.pth"

RUN echo "Downloading A-Detailer models..."
RUN hf download IgorGent/pony \
    --local-dir models/adetailer \
    --local-dir-use-symlinks False \
    --include "A-Detailer/*.pt"


# Verify ReActor models were downloaded
RUN echo "Verifying ReActor models..."
RUN ls -la models/insightface/ || echo "No models found in models/insightface"
RUN ls -la models/insightface/models/ || echo "No models found in models/insightface/models"
RUN ls -la models/facedetection/ || echo "No models found in models/facedetection"
RUN ls -la models/facerestore_models/ || echo "No models found in models/facerestore_models"
RUN ls -la models/nsfw_detector/ || echo "No models found in models/nsfw_detector"
RUN ls -la models/nsfw_detector/vit-base-nsfw-detector/ || echo "No models found in models/nsfw_detector/vit-base-nsfw-detector"
RUN ls -la models/clip_vision/ || echo "No models found in models/clip_vision"
RUN ls -la models/clip_interrogator/ || echo "No models found in models/clip_interrogator"
RUN ls -la models/prompt_generator/ || echo "No models found in models/prompt_generator"
RUN if [ -f "models/insightface/inswapper_128.onnx" ]; then echo "inswapper_128.onnx downloaded successfully"; else echo "inswapper_128.onnx download failed"; fi
RUN if [ -f "models/insightface/models/buffalo_l/1k3d68.onnx" ]; then echo "buffalo_l model downloaded successfully"; else echo "buffalo_l model download failed"; fi
RUN if [ -f "models/facedetection/detection_Resnet50_Final.pth" ]; then echo "detection_Resnet50_Final.pth downloaded successfully"; else echo "detection_Resnet50_Final.pth download failed"; fi
RUN if [ -f "models/facedetection/parsing_parsenet.pth" ]; then echo "parsing_parsenet.pth downloaded successfully"; else echo "parsing_parsenet.pth download failed"; fi
RUN if [ -f "models/facerestore_models/GFPGANv1.4.pth" ]; then echo "GFPGANv1.4.pth downloaded successfully"; else echo "GFPGANv1.4.pth download failed"; fi
RUN if [ -f "models/nsfw_detector/vit-base-nsfw-detector/model.safetensors" ]; then echo "NSFW detector model downloaded successfully"; else echo "NSFW detector model download failed"; fi
RUN if [ -f "models/ultralytics/bbox/face_yolov8m.pt" ]; then echo "YOLO face detection model downloaded successfully"; else echo "YOLO face detection model download failed"; fi
RUN if [ -f "models/ultralytics/bbox/hand_yolov8s.pt" ]; then echo "YOLO hand detection model downloaded successfully"; else echo "YOLO hand detection model download failed"; fi
RUN if [ -f "models/ultralytics/segm/person_yolov8m-seg.pt" ]; then echo "YOLO person segmentation model downloaded successfully"; else echo "YOLO person segmentation model download failed"; fi

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