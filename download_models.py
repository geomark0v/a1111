from huggingface_hub import hf_hub_download
import os

VOLUME = "/runpod-volume"

def download(repo, filename, subfolder=None, local_dir=None):
    local_dir = local_dir or VOLUME
    path = hf_hub_download(
        repo_id=repo,
        filename=filename,
        subfolder=subfolder,
        local_dir=local_dir,
        local_dir_use_symlinks=False
    )
    print(f"✅ Downloaded: {path}")

# Pony модели
for model in [
    "cyberrealisticPony_v141.safetensors",
    "cyberrealisticPony_v141 (1).safetensors",
    "cyberrealisticPony_v150bf16.safetensors",
    "cyberrealisticPony_v150.safetensors"
]:
    download("IgorGent/pony", model, local_dir=os.path.join(VOLUME, "models", "Stable-diffusion"))

# ControlNet модели (IP-Adapter, InstantID)
controlnet_dir = os.path.join(VOLUME, "extensions", "sd-webui-controlnet", "models")
for file in [
    "ip-adapter-faceid-plusv2_sdxl.bin",
    "ip-adapter-faceid-plusv2_sdxl_lora.safetensors",
    "ip-adapter-plus-face_sdxl_vit-h.safetensors",
    "clip_h.pth",
    "control_instant_id_sdxl.safetensors"
]:
    download("IgorGent/pony", file, local_dir=controlnet_dir)

# ReActor ONNX
reactor_dir = os.path.join(VOLUME, "extensions", "sd-webui-reactor", "models")
for onnx in ["inswapper_128.onnx", "1k3d68.onnx", "2d106det.onnx"]:
    download("IgorGent/pony", onnx, local_dir=reactor_dir)

print("🎉 All models ready!")