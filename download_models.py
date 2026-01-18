# download_models.py
"""
Скрипт скачивает все модели в правильные пути для ComfyUI
Место сохранения: /workspace/comfyui/models/...
"""

import os
import sys
import requests
import time
from pathlib import Path
from huggingface_hub import hf_hub_download

# Основная директория моделей в ComfyUI
MODELS_DIR = Path("/workspace/comfyui/models")
MODELS_DIR.mkdir(parents=True, exist_ok=True)

# Токен Hugging Face (если приватные репозитории)
HF_TOKEN = os.getenv("HUGGINGFACE_ACCESS_TOKEN")

def hf_download(repo_id, filename, subdir=""):
    """Скачивание файла с Hugging Face в указанную подпапку ComfyUI"""
    target_dir = MODELS_DIR / subdir
    target_dir.mkdir(parents=True, exist_ok=True)

    target_path = target_dir / Path(filename).name

    if target_path.exists() and target_path.stat().st_size > 0:
        print(f"[SKIP] {filename} уже существует в {target_path}")
        return

    print(f"[DOWNLOAD] {filename} из {repo_id} → {target_dir}")

    max_retries = 5
    for attempt in range(1, max_retries + 1):
        try:
            hf_hub_download(
                repo_id=repo_id,
                filename=filename,
                local_dir=target_dir,
                local_dir_use_symlinks=False,
                token=HF_TOKEN if HF_TOKEN else None,
                resume_download=True,
                force_download=False
            )
            print(f"[OK] {filename}")
            return
        except Exception as e:
            print(f"[Попытка {attempt}/{max_retries}] Ошибка: {e}")
            if "name resolution" in str(e) or "Max retries" in str(e):
                time.sleep(10)  # ждём при DNS/сетевых проблемах
            else:
                break
    print(f"[ERROR] Не удалось скачать {filename} после {max_retries} попыток")

def wget_download(url, target_path):
    """Прямое скачивание по URL (для swapify, github и т.п.)"""
    target_path = Path(target_path)
    target_path.parent.mkdir(parents=True, exist_ok=True)

    if target_path.exists() and target_path.stat().st_size > 0:
        print(f"[SKIP] {target_path.name} уже существует")
        return

    print(f"[DOWNLOAD] {url} → {target_path}")

    max_retries = 5
    for attempt in range(1, max_retries + 1):
        try:
            r = requests.get(url, stream=True, timeout=60)
            r.raise_for_status()
            with open(target_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
            print(f"[OK] {target_path.name}")
            return
        except Exception as e:
            print(f"[Попытка {attempt}/{max_retries}] Ошибка: {e}")
            time.sleep(5)
    print(f"[ERROR] Не удалось скачать {url} после {max_retries} попыток")


if __name__ == "__main__":
    print("=== Запуск скачивания моделей для ComfyUI ===")

    # 1. UNET & CLIP fp8 (Qwen)
    hf_download("lightx2v/Qwen-Image-Lightning", "Qwen-Image-Edit-2509/qwen_image_edit_2509_fp8_e4m3fn_scaled.safetensors", "unet")
    hf_download("Comfy-Org/z_image_turbo", "split_files/diffusion_models/z_image_turbo_bf16.safetensors", "unet")

    hf_download("Comfy-Org/Qwen-Image_ComfyUI", "split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors", "clip")
    hf_download("Comfy-Org/z_image_turbo", "split_files/text_encoders/qwen_3_4b.safetensors", "clip")

    # 2. VAE
    hf_download("Comfy-Org/Qwen-Image_ComfyUI", "split_files/vae/qwen_image_vae.safetensors", "vae")
    hf_download("Comfy-Org/z_image_turbo", "split_files/vae/ae.safetensors", "vae")

    # 3. LoRA модели
    hf_download("lightx2v/Qwen-Image-Lightning", "Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-8steps-V1.0-bf16.safetensors", "loras")
    hf_download("lightx2v/Qwen-Image-Lightning", "Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors", "loras")

    wget_download("https://studio.swapify.link/assets/Qwen-Image-Analog-v1.1.safetensors",
                  "models/loras/Qwen-Image-Analog-v1.1.safetensors")

    wget_download("https://studio.swapify.link/assets/lenovo.safetensors",
                  "models/loras/lenovo.safetensors")

    hf_download("valiantcat/Qwen-Image-Edit-2509-photous", "QwenEdit2509_photous_000010000.safetensors", "loras")
    hf_download("tlennon-ie/qwen-edit-skin", "qwen-edit-skin_1.1_000002750.safetensors", "loras")

    # 4. Upscale model
    hf_download("wavespeed/misc", "upscalers/4xLSDIR.pth", "upscale_models")

    # 5. ReActor models
    print("\nDownloading ReActor models...")
    wget_download("https://app.swapify.link/assets/inswapper_128.onnx", "models/insightface/inswapper_128.onnx")
    wget_download("https://app.swapify.link/assets/detection_Resnet50_Final.pth", "models/facedetection/detection_Resnet50_Final.pth")
    wget_download("https://app.swapify.link/assets/GFPGANv1.4.pth", "models/facerestore_models/GFPGANv1.4.pth")

    # 6. NSFW detector
    print("\nDownloading NSFW detector models...")
    Path("models/nsfw_detector/vit-base-nsfw-detector").mkdir(parents=True, exist_ok=True)
    hf_download("AdamCodd/vit-base-nsfw-detector", "config.json", "nsfw_detector/vit-base-nsfw-detector")
    hf_download("AdamCodd/vit-base-nsfw-detector", "model.safetensors", "nsfw_detector/vit-base-nsfw-detector")
    hf_download("AdamCodd/vit-base-nsfw-detector", "preprocessor_config.json", "nsfw_detector/vit-base-nsfw-detector")

    # 7. Additional ReActor models (buffalo_l + parsing)
    print("\nDownloading additional ReActor models...")
    Path("models/insightface/models/buffalo_l").mkdir(parents=True, exist_ok=True)
    wget_download("https://app.swapify.link/assets/buffalo_l/1k3d68.onnx", "models/insightface/models/buffalo_l/1k3d68.onnx")
    wget_download("https://app.swapify.link/assets/buffalo_l/2d106det.onnx", "models/insightface/models/buffalo_l/2d106det.onnx")
    wget_download("https://app.swapify.link/assets/buffalo_l/det_10g.onnx", "models/insightface/models/buffalo_l/det_10g.onnx")
    wget_download("https://app.swapify.link/assets/buffalo_l/genderage.onnx", "models/insightface/models/buffalo_l/genderage.onnx")
    wget_download("https://app.swapify.link/assets/buffalo_l/w600k_r50.onnx", "models/insightface/models/buffalo_l/w600k_r50.onnx")

    wget_download("https://github.com/sczhou/CodeFormer/releases/download/v0.1.0/parsing_parsenet.pth",
                  "models/facedetection/parsing_parsenet.pth")

    # 8. YOLO models
    print("\nDownloading YOLO models for detection and segmentation...")
    Path("models/ultralytics/bbox").mkdir(parents=True, exist_ok=True)
    Path("models/ultralytics/segm").mkdir(parents=True, exist_ok=True)
    wget_download("https://app.swapify.link/assets/face_yolov8m.pt", "models/ultralytics/bbox/face_yolov8m.pt")
    wget_download("https://app.swapify.link/assets/hand_yolov8s.pt", "models/ultralytics/bbox/hand_yolov8s.pt")
    wget_download("https://app.swapify.link/assets/person_yolov8m-seg.pt", "models/ultralytics/segm/person_yolov8m-seg.pt")

    # 9. Pony checkpoints (A1111 adapted → ComfyUI checkpoints)
    print("\nDownloading main generation models...")
    hf_download("IgorGent/pony", "cyberrealisticPony_v141.safetensors", "checkpoints")
    hf_download("IgorGent/pony", "cyberrealisticPony_v141 (1).safetensors", "checkpoints")
    hf_download("IgorGent/pony", "cyberrealisticPony_v150bf16.safetensors", "checkpoints")
    hf_download("IgorGent/pony", "cyberrealisticPony_v150.safetensors", "checkpoints")

    # 10. ControlNet and related
    print("\nDownloading ControlNet and related models...")
    hf_download("IgorGent/pony", "ip-adapter-faceid-plusv2_sdxl.bin", "controlnet")
    hf_download("IgorGent/pony", "ip-adapter-faceid-plusv2_sdxl_lora.safetensors", "loras")
    hf_download("IgorGent/pony", "ip-adapter-plus-face_sdxl_vit-h.safetensors", "controlnet")
    hf_download("IgorGent/pony", "ip-adapter-plus_sdxl_vit-h (1).safetensors", "controlnet")
    hf_download("IgorGent/pony", "ip-adapter_sdxl_vit-h (1).safetensors", "controlnet")
    hf_download("IgorGent/pony", "clip_h.pth", "clip_vision")
    hf_download("IgorGent/pony", "ip_adapter_instant_id_sdxl.bin", "controlnet")
    hf_download("IgorGent/pony", "control_instant_id_sdxl.safetensors", "controlnet")

    # 11. insightface antelopev2
    print("\nDownloading insightface antelopev2 models...")
    Path("models/insightface/models/antelopev2").mkdir(parents=True, exist_ok=True)
    hf_download("IgorGent/pony", "1k3d68.onnx", "insightface/models/antelopev2")
    hf_download("IgorGent/pony", "2d106det.onnx", "insightface/models/antelopev2")
    hf_download("IgorGent/pony", "genderage.onnx", "insightface/models/antelopev2")
    hf_download("IgorGent/pony", "glintr100.onnx", "insightface/models/antelopev2")
    hf_download("IgorGent/pony", "scrfd_10g_bnkps.onnx", "insightface/models/antelopev2")

    # 12. CodeFormer + parsing
    print("\nDownloading CodeFormer and GFPGAN models...")
    hf_download("IgorGent/pony", "codeformer-v0.1.0.pth", "codeformer")
    hf_download("IgorGent/pony", "parsing_bisenet.pth", "facedetection")
    hf_download("IgorGent/pony", "parsing_parsenet.pth", "facedetection")
    hf_download("IgorGent/pony", "codeformer.pth", "codeformer")

    # 13. A-Detailer
    print("\nDownloading A-Detailer models...")
    hf_download("IgorGent/pony", "A-Detailer/Eyeful_v1 (3).pt", "adetailer")
    hf_download("IgorGent/pony", "A-Detailer/Eyes (1) (2).pt", "adetailer")
    hf_download("IgorGent/pony", "A-Detailer/Eyes (4).pt", "adetailer")
    hf_download("IgorGent/pony", "A-Detailer/FacesV1 (2).pt", "adetailer")
    hf_download("IgorGent/pony", "A-Detailer/face_yolov8m (2).pt", "adetailer")
    hf_download("IgorGent/pony", "A-Detailer/penis (1) (2).pt", "adetailer")
    hf_download("IgorGent/pony", "A-Detailer/penis (3).pt", "adetailer")

    print("\n=== Скачивание всех моделей завершено! ===")