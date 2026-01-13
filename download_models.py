from huggingface_hub import hf_hub_download
import os
import sys

VOLUME = "/runpod-volume"
FORGE_ROOT = os.path.join(VOLUME, "stable-diffusion-webui")

def download_single(repo, filename, local_dir, new_filename=None):
    local_path = os.path.join(local_dir, new_filename or filename)
    if os.path.exists(local_path):
        print(f"[SKIP] {filename} already exists as {local_path}")
        return
    print(f"[DOWNLOAD] {filename}...")
    try:
        hf_hub_download(
            repo_id=repo,
            filename=filename,
            local_dir=local_dir,
            local_dir_use_symlinks=False
        )
        # Переименовываем, если нужно
        old_path = os.path.join(local_dir, filename)
        if new_filename and os.path.exists(old_path):
            os.rename(old_path, local_path)
        print(f"[OK] {filename} downloaded to {local_path}")
    except Exception as e:
        print(f"[ERROR] Failed to download {filename}: {e}")
        sys.exit(1)

# Создаём все нужные папки
os.makedirs(os.path.join(FORGE_ROOT, "models", "Stable-diffusion"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "ControlNet"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "Lora"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "clip_vision"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "insightface", "models", "antelopev2"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "insightface", "models", "buffalo_l"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "insightface"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "Codeformer"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "GFPGAN"), exist_ok=True)
os.makedirs(os.path.join(FORGE_ROOT, "models", "adetailer"), exist_ok=True)

# Pony модели
pony_dir = os.path.join(FORGE_ROOT, "models", "Stable-diffusion")
download_single("IgorGent/pony", "cyberrealisticPony_v141.safetensors", pony_dir)
download_single("IgorGent/pony", "cyberrealisticPony_v141 (1).safetensors", pony_dir, new_filename="cyberrealisticPony_v141_alt.safetensors")
download_single("IgorGent/pony", "cyberrealisticPony_v150bf16.safetensors", pony_dir)
download_single("IgorGent/pony", "cyberrealisticPony_v150.safetensors", pony_dir)

# ControlNet модели
controlnet_dir = os.path.join(FORGE_ROOT, "models", "ControlNet")
download_single("IgorGent/pony", "ip-adapter-faceid-plusv2_sdxl.bin", controlnet_dir)
download_single("IgorGent/pony", "ip-adapter-faceid-plusv2_sdxl_lora.safetensors", controlnet_dir)
download_single("IgorGent/pony", "ip-adapter-plus-face_sdxl_vit-h.safetensors", controlnet_dir)
download_single("IgorGent/pony", "ip-adapter-plus_sdxl_vit-h (1).safetensors", controlnet_dir, new_filename="ip-adapter-plus_sdxl_vit-h_alt.safetensors")
download_single("IgorGent/pony", "ip-adapter_sdxl_vit-h (1).safetensors", controlnet_dir, new_filename="ip-adapter_sdxl_vit-h_alt.safetensors")
download_single("IgorGent/pony", "clip_h.pth", os.path.join(FORGE_ROOT, "models", "clip_vision"))
download_single("IgorGent/pony", "ip_adapter_instant_id_sdxl.bin", controlnet_dir)
download_single("IgorGent/pony", "control_instant_id_sdxl.safetensors", controlnet_dir)

# ReActor ONNX
reactor_dir = os.path.join(FORGE_ROOT, "extensions", "sd-webui-reactor", "models")
download_single("IgorGent/pony", "inswapper_128.onnx", reactor_dir)

# Insightface antelopev2
antelope_dir = os.path.join(FORGE_ROOT, "models", "insightface", "models", "antelopev2")
download_single("IgorGent/pony", "1k3d68.onnx", antelope_dir)
download_single("IgorGent/pony", "2d106det.onnx", antelope_dir)
download_single("IgorGent/pony", "genderage.onnx", antelope_dir)
download_single("IgorGent/pony", "glintr100.onnx", antelope_dir)
download_single("IgorGent/pony", "scrfd_10g_bnkps.onnx", antelope_dir)

# Insightface buffalo_l
buffalo_dir = os.path.join(FORGE_ROOT, "models", "insightface", "models", "buffalo_l")
download_single("IgorGent/pony", "det_10g.onnx", buffalo_dir)
download_single("IgorGent/pony", "w600k_r50.onnx", buffalo_dir)

# Codeformer и GFPGAN
codeformer_dir = os.path.join(FORGE_ROOT, "models", "Codeformer")
download_single("IgorGent/pony", "codeformer-v0.1.0.pth", codeformer_dir)
download_single("IgorGent/pony", "codeformer.pth", codeformer_dir)

gfpgan_dir = os.path.join(FORGE_ROOT, "models", "GFPGAN")
download_single("IgorGent/pony", "GFPGANv1.4.pth", gfpgan_dir)
download_single("IgorGent/pony", "detection_Resnet50_Final.pth", gfpgan_dir)
download_single("IgorGent/pony", "parsing_bisenet.pth", gfpgan_dir)
download_single("IgorGent/pony", "parsing_parsenet.pth", gfpgan_dir)

# A-Detailer (скачиваем всю папку)
adetailer_dir = os.path.join(FORGE_ROOT, "models", "adetailer")
if not os.path.exists(adetailer_dir):
    print("[DOWNLOAD TREE] A-Detailer models...")
    snapshot_download(repo_id="IgorGent/pony", allow_patterns="A-Detailer/*", local_dir=adetailer_dir, local_dir_use_symlinks=False)
else:
    print("[SKIP] A-Detailer directory already exists")

print("🎉 All models ready!")