# config.py
BASE = "/runpod-volume"
MODEL_DIR = f"{BASE}/models"

# SDXL
SDXL_FILES = [
    "cyberrealisticPony_v150.safetensors",
    "cyberrealisticPony_v141.safetensors"
]

# ControlNet / IP-Adapter
CONTROLNET_FILES = [
    "ip-adapter-faceid-plusv2_sdxl.bin",
    "ip-adapter-faceid-plusv2_sdxl_lora.safetensors",
    "ip-adapter-plus-face_sdxl_vit-h.safetensors",
    "ip-adapter-plus_sdxl_vit-h_alt.safetensors",
    "ip-adapter_sdxl_vit-h_alt.safetensors",
    "clip_h.pth",
    "ip_adapter_instant_id_sdxl.bin",
    "control_instant_id_sdxl.safetensors",
]

# ReActor
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

# GFPGAN / CodeFormer
GFPGAN_FILES = ["GFPGANv1.4.pth"]
CODEFORMER_FILES = ["codeformer.pth", "codeformer-v0.1.0.pth"]

# ADetailer
ADETAILER_FILES = ["face_yolov8n.pt"]
