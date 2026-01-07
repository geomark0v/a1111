import os
from pathlib import Path
import torch
from diffusers import StableDiffusionXLPipeline
import subprocess
from config import BASE, MODEL_DIR, SDXL_FILES, CONTROLNET_FILES, REACTOR_FILES, GFPGAN_FILES, CODEFORMER_FILES, ADETAILER_FILES

def get_sdxl_pipeline(checkpoint="cyberrealisticPony_v150.safetensors"):
    path = Path(MODEL_DIR) / "Stable-diffusion" / checkpoint
    print(f"🔥 Loading SDXL pipeline from {path}")
    pipe = StableDiffusionXLPipeline.from_single_file(path, torch_dtype=torch.float16)
    pipe.to("cuda")
    pipe.enable_xformers_memory_efficient_attention()
    pipe.enable_model_cpu_offload()
    print("✅ SDXL pipeline loaded")
    return pipe

def check_models(folder, files):
    path = Path(folder)
    if not path.exists():
        print(f"⚠️ {folder} does not exist")
    for f in files:
        if not (path / f).exists():
            print(f"⚠️ Missing file {f} in {folder}")
    print(f"✅ Checked {folder}")

def preload_all():
    # SDXL
    pipe = get_sdxl_pipeline(SDXL_FILES[0])

    # ControlNet
    check_models(os.path.join(BASE, "extensions", "sd-webui-controlnet", "models"), CONTROLNET_FILES)

    # ReActor
    check_models(os.path.join(BASE, "extensions", "sd-webui-reactor", "models"), REACTOR_FILES)

    # GFPGAN / CodeFormer
    check_models(os.path.join(MODEL_DIR, "GFPGAN"), GFPGAN_FILES)
    check_models(os.path.join(MODEL_DIR, "Codeformer"), CODEFORMER_FILES)

    # ADetailer
    check_models(os.path.join(BASE, "extensions", "adetailer", "models"), ADETAILER_FILES)

    print("✅ All models preloaded. Forge API ready!")

if __name__ == "__main__":
    print("🚀 Cold start preload...")
    preload_all()

   # путь к оригинальному Forge launch.py
   FORGE_LAUNCH = "/workspace/stable-diffusion-webui-forge/launch.py"

   cmd = [
       "python3", FORGE_LAUNCH,
       "--listen",
       "--port", "8080",
       "--api",
       "--skip-torch-cuda-test",
       "--no-half-vae",
       "--opt-sdp-no-mem-attention",
       "--xformers"
   ]

   subprocess.run(cmd, check=True)
