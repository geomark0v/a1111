# download_models.py
import os
import subprocess
from huggingface_hub import hf_hub_download
from config import BASE, MODEL_DIR, SDXL_FILES, IP_ADAPTER_FILES, GFPGAN_FILES, CODEFORMER_FILES, CONTROLNET_REPO, REACTOR_FILES, REACTOR_REPO, ADETAILER_REPO

# Создаём папки
os.makedirs(MODEL_DIR, exist_ok=True)

def download_hf_files(file_list, subfolder=""):
    target_dir = os.path.join(MODEL_DIR, subfolder)
    os.makedirs(target_dir, exist_ok=True)
    for filename in file_list:
        print(f"Downloading {filename} → {target_dir}")
        hf_hub_download(
            repo_id="IgorGent/pony",
            filename=filename,
            cache_dir=target_dir,
            force_download=False
        )

# SDXL модели
download_hf_files(SDXL_FILES, "Stable-diffusion")

# IP-Adapter / ControlNet модели
download_hf_files(IP_ADAPTER_FILES, "extensions/sd-webui-controlnet/models")

# ReActor модели
download_hf_files(REACTOR_FILES, "extensions/sd-webui-reactor/models")

# GFPGAN / CodeFormer
download_hf_files(GFPGAN_FILES, "models/GFPGAN")
download_hf_files(CODEFORMER_FILES, "models/Codeformer")

# Клонируем ControlNet и ReActor репозитории (runtime)
controlnet_dir = os.path.join(MODEL_DIR, "extensions", "sd-webui-controlnet")
if not os.path.exists(controlnet_dir):
    subprocess.run(["git", "clone", CONTROLNET_REPO, controlnet_dir], che
