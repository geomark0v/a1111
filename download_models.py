import os
from huggingface_hub import hf_hub_download
from config import BASE, MODEL_DIR, SDXL_FILES, CONTROLNET_FILES, REACTOR_FILES, GFPGAN_FILES, CODEFORMER_FILES, ADETAILER_FILES

def download(repo, filename, target_dir):
    os.makedirs(target_dir, exist_ok=True)
    path = os.path.join(target_dir, filename)
    if os.path.exists(path):
        print(f"✔ {filename} already exists, skipping")
        return path
    print(f"⬇ Downloading {filename}")
    return hf_hub_download(
        repo_id=repo,
        filename=filename,
        local_dir=target_dir,
        local_dir_use_symlinks=False
    )

def download_all():
    repo = "IgorGent/pony"

    # SDXL
    sd_dir = os.path.join(MODEL_DIR, "Stable-diffusion")
    for f in SDXL_FILES:
        download(repo, f, sd_dir)

    # ControlNet
    cn_dir = os.path.join(BASE, "extensions", "sd-webui-controlnet", "models")
    for f in CONTROLNET_FILES:
        download(repo, f, cn_dir)

    # ReActor
    reactor_dir = os.path.join(BASE, "extensions", "sd-webui-reactor", "models")
    for f in REACTOR_FILES:
        download(repo, f, reactor_dir)

    # GFPGAN
    gfpgan_dir = os.path.join(MODEL_DIR, "GFPGAN")
    for f in GFPGAN_FILES:
        download(repo, f, gfpgan_dir)

    # CodeFormer
    codeformer_dir = os.path.join(MODEL_DIR, "Codeformer")
    for f in CODEFORMER_FILES:
        download(repo, f, codeformer_dir)

    # ADetailer
    adetailer_dir = os.path.join(BASE, "extensions", "adetailer", "models")
    for f in ADETAILER_FILES:
        download(repo, f, adetailer_dir)

    print("✅ All models are downloaded and ready!")

if __name__ == "__main__":
    download_all()
