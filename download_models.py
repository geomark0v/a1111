import os
from huggingface_hub import hf_hub_download

BASE = "/runpod-volume"
MODEL_DIR = f"{BASE}/models"

def download(repo, filename, target_dir):
    os.makedirs(target_dir, exist_ok=True)
    path = os.path.join(target_dir, filename)
    if os.path.exists(path):
        return path
    print(f"⬇ Downloading {filename}")
    return hf_hub_download(
        repo_id=repo,
        filename=filename,
        local_dir=target_dir,
        local_dir_use_symlinks=False
    )

def download_all_models():
    repo = "IgorGent/pony"

    # Stable Diffusion
    sd_dir = f"{MODEL_DIR}/Stable-diffusion"
    for f in [
        "cyberrealisticPony_v141.safetensors",
        "cyberrealisticPony_v141_alt.safetensors",
        "cyberrealisticPony_v150bf16.safetensors",
        "cyberrealisticPony_v150.safetensors",
    ]:
        download(repo, f, sd_dir)

    # ControlNet / IP-Adapter
    cn_dir = f"{BASE}/extensions/sd-webui-controlnet/models"
    for f in [
        "ip-adapter-faceid-plusv2_sdxl.bin",
        "ip-adapter-faceid-plusv2_sdxl_lora.safetensors",
        "ip-adapter-plus-face_sdxl_vit-h.safetensors",
        "ip-adapter-plus_sdxl_vit-h_alt.safetensors",
        "ip-adapter_sdxl_vit-h_alt.safetensors",
        "clip_h.pth",
        "ip_adapter_instant_id_sdxl.bin",
        "control_instant_id_sdxl.safetensors",
    ]:
        download(repo, f, cn_dir)

    # ReActor
    reactor_dir = f"{BASE}/extensions/sd-webui-reactor/models"
    for f in [
        "inswapper_128.onnx",
        "1k3d68.onnx",
        "2d106det.onnx",
        "genderage.onnx",
        "glintr100.onnx",
        "scrfd_10g_bnkps.onnx",
        "det_10g.onnx",
        "w600k_r50.onnx",
    ]:
        download(repo, f, reactor_dir)

    # GFPGAN / CodeFormer
    download(repo, "GFPGANv1.4.pth", f"{MODEL_DIR}/GFPGAN")
    download(repo, "codeformer.pth", f"{MODEL_DIR}/Codeformer")
    download(repo, "codeformer-v0.1.0.pth", f"{MODEL_DIR}/Codeformer")

download_all_models()
print("✅ All models downloaded and ready for Forge API")
