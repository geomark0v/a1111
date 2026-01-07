FROM runpod/a1111:latest

USER root

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    python3-dev \
    libopencv-dev \
    libglib2.0-0 \
    libsm6 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir insightface==0.7.3 onnxruntime-gpu

WORKDIR /workspace/stable-diffusion-webui

RUN git clone https://github.com/Mikubill/sd-webui-controlnet extensions/sd-webui-controlnet && \
    git clone https://codeberg.org/Gourieff/sd-webui-reactor.git extensions/sd-webui-reactor && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/deforum-art/sd-webui-deforum extensions/sd-webui-deforum && \
    git clone https://github.com/ototadana/sd-face-editor.git extensions/sd-face-editor

RUN pip install --no-cache-dir ultralytics

RUN mkdir -p models/Stable-diffusion && \
    cd models/Stable-diffusion && \
    wget -O cyberrealisticPony_v141.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141.safetensors" && \
    wget -O cyberrealisticPony_v141_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v141%20(1).safetensors" && \
    wget -O cyberrealisticPony_v150bf16.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150bf16.safetensors" && \
    wget -O cyberrealisticPony_v150.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/cyberrealisticPony_v150.safetensors"

RUN mkdir -p extensions/sd-webui-controlnet/models && \
    cd extensions/sd-webui-controlnet/models && \
    wget -O ip-adapter-faceid-plusv2_sdxl.bin "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-faceid-plusv2_sdxl.bin" && \
    wget -O ip-adapter-faceid-plusv2_sdxl_lora.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-faceid-plusv2_sdxl_lora.safetensors" && \
    wget -O ip-adapter-plus-face_sdxl_vit-h.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-plus-face_sdxl_vit-h.safetensors" && \
    wget -O ip-adapter-plus_sdxl_vit-h_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter-plus_sdxl_vit-h%20(1).safetensors" && \
    wget -O ip-adapter_sdxl_vit-h_(1).safetensors "https://huggingface.co/IgorGent/pony/resolve/main/ip-adapter_sdxl_vit-h%20(1).safetensors" && \
    wget -O clip_h.pth "https://huggingface.co/IgorGent/pony/resolve/main/clip_h.pth" && \
    wget -O ip_adapter_instant_id_sdxl.bin "https://huggingface.co/IgorGent/pony/resolve/main/ip_adapter_instant_id_sdxl.bin" && \
    wget -O control_instant_id_sdxl.safetensors "https://huggingface.co/IgorGent/pony/resolve/main/control_instant_id_sdxl.safetensors"

RUN mkdir -p extensions/sd-webui-reactor/models && \
    cd extensions/sd-webui-reactor/models && \
    wget -O inswapper_128.onnx "https://huggingface.co/IgorGent/pony/resolve/main/inswapper_128.onnx" && \
    wget -O 1k3d68.onnx "https://huggingface.co/IgorGent/pony/resolve/main/1k3d68.onnx" && \
    wget -O 2d106det.onnx "https://huggingface.co/IgorGent/pony/resolve/main/2d106det.onnx" && \
    wget -O genderage.onnx "https://huggingface.co/IgorGent/pony/resolve/main/genderage.onnx" && \
    wget -O glintr100.onnx "https://huggingface.co/IgorGent/pony/resolve/main/glintr100.onnx" && \
    wget -O scrfd_10g_bnkps.onnx "https://huggingface.co/IgorGent/pony/resolve/main/scrfd_10g_bnkps.onnx" && \
    wget -O det_10g.onnx "https://huggingface.co/IgorGent/pony/resolve/main/det_10g.onnx" && \
    wget -O w600k_r50.onnx "https://huggingface.co/IgorGent/pony/resolve/main/w600k_r50.onnx"

RUN mkdir -p models/GFPGAN models/Codeformer && \
    cd models/GFPGAN && \
    wget -O GFPGANv1.4.pth "https://huggingface.co/IgorGent/pony/resolve/main/GFPGANv1.4.pth" && \
    cd ../Codeformer && \
    wget -O codeformer.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer.pth" && \
    wget -O codeformer-v0.1.0.pth "https://huggingface.co/IgorGent/pony/resolve/main/codeformer-v0.1.0.pth"

USER runpod

CMD ["--listen", "--port", "8080", "--api"]