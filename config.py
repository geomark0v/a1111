# config.py

# Network Volume (ОБЯЗАТЕЛЬНО)
BASE = "/runpod-volume"
MODEL_DIR = f"{BASE}/models"

# Репозиторий HF
HF_REPO = "IgorGent/pony"

# ================= SDXL =================
SDXL_FILES = [
    "cyberrealisticPony_v141.safetensors",
    "cyberrealisticPony_v141 (1).safetensors",
    "cyberrealisticPony_v150bf16.safetensors",
    "cyberrealisticPony_v150.safetensors",
]

# ================= ControlNet / IP-Adapter =================
CONTROLNET_REPO = "https://github.com/Mikubill/sd-webui-controlnet"

IP_ADAPTER_FILES = [
    "ip-adapter-faceid-plusv2_sdxl.bin",
    "ip-adapter-faceid-plusv2_sdxl_lora.safetensors",
    "ip-adapter-plus-face_sdxl_vit-h.safetensors",
    "ip-adapter-plus_sdxl_vit-h (1).safetensors",
    "ip-adapter_sdxl_vit-h (1).safetensors",
    "clip_h.pth",
    "ip_adapter_instant_id_sdxl.bin",
    "control_instant_id_sdxl.safetensors",
]

# ================= ReActor =================
REACTOR_REPO = "https://codeberg.org/Gourieff/sd-webui-reactor.git"

REACTOR_FILES = [
    "inswapper_128.onnx",
    "1k3d68.onnx",
    "2d106det.onnx",
    "genderage.onnx",
    "glintr100.onnx",
    "scrfd_10g_bnkps.onnx",
    "det_10g.onnx",
    "w600k_r50.onnx",
]

# ================= GFPGAN / CodeFormer =================
GFPGAN_FILES = [
    "GFPGANv1.4.pth"
]

CODEFORMER_FILES = [
    "codeformer.pth",
    "codeformer-v0.1.0.pth"
]
