import runpod
import requests
import time
import subprocess
import os
import threading
import random

# Пути
FORGE_DIR = "/workspace/stable-diffusion-webui-forge"
LAUNCH_PY = os.path.join(FORGE_DIR, "launch.py")
API_URL = "http://127.0.0.1:8080"

# Хранилище результатов: client_job_id → данные
results_store = {}
store_lock = threading.Lock()

def start_forge():
    print("Запуск Stable Diffusion WebUI Forge...")
    subprocess.Popen([
        "python", LAUNCH_PY,
        "--listen",
        "--port", "8080",
        "--api",
        "--skip-torch-cuda-test",
        "--no-half-vae",
        "--opt-sdp-no-mem-attention",
        "--disable-nan-check"
    ], cwd=FORGE_DIR)

def wait_for_api(timeout=180):
    print("Ожидание готовности API...")
    for _ in range(timeout):
        try:
            resp = requests.get(f"{API_URL}/sdapi/v1/sd-models", timeout=10)
            if resp.status_code == 200:
                print("Forge API готов!")
                return
        except:
            time.sleep(1)
    raise TimeoutError("Forge не запустился")

start_forge()
wait_for_api()

def run_generation(client_job_id: str, payload: dict):
    try:
        with store_lock:
            results_store[client_job_id] = {
                "status": "in_progress",
                "progress": 0.0,
                "current_step": 0,
                "total_steps": payload.get("steps", 30),
                "images": None,
                "info": None
            }

        print(f"[Job: {client_job_id}] Генерация начата")

        response = requests.post(f"{API_URL}/sdapi/v1/txt2img", json=payload, timeout=1800)
        response.raise_for_status()
        result = response.json()

        with store_lock:
            results_store[client_job_id] = {
                "status": "completed",
                "progress": 1.0,
                "current_step": payload.get("steps", 30),
                "total_steps": payload.get("steps", 30),
                "images": result.get("images", []),
                "info": result.get("info", ""),
                "parameters": result.get("parameters", {})
            }
        print(f"[Job: {client_job_id}] Завершено успешно")

    except Exception as e:
        error_msg = str(e)
        print(f"[Job: {client_job_id}] Ошибка: {error_msg}")
        with store_lock:
            results_store[client_job_id] = {
                "status": "failed",
                "error": error_msg
            }

def handler(job):
    # action теперь на верхнем уровне!
    action = job.get("action")
    input_data = job.get("input", {})
    client_job_id = job.get("job_id")  # опционально на верхнем уровне

    if not action:
        return {"error": "Поле 'action' обязательно на верхнем уровне. Доступно: generate, status, result"}

    # === 1. Запуск генерации ===
    if action == "generate":
        # Если job_id не передан — генерируем автоматически
        if not client_job_id:
            client_job_id = f"gen_{int(time.time())}_{random.randint(1000, 9999)}"

        payload = {
            "prompt": input_data.get("prompt", ""),
            "negative_prompt": input_data.get("negative_prompt", ""),
            "seed": input_data.get("seed", -1),
            "steps": input_data.get("steps", 30),
            "cfg_scale": input_data.get("cfg_scale", 7),
            "width": input_data.get("width", 768),
            "height": input_data.get("height", 1024),
            "sampler_name": input_data.get("sampler_name", "DPM++ 2M SDE Karras"),
            "scheduler": input_data.get("scheduler", "Karras"),
            "override_settings": input_data.get("override_settings", {}),
            "alwayson_scripts": input_data.get("alwayson_scripts", {}),
        }
        if "init_images" in input_data:
            payload["init_images"] = input_data["init_images"]

        threading.Thread(target=run_generation, args=(client_job_id, payload)).start()

        return {
            "job_id": client_job_id,
            "status": "queued",
            "message": "Генерация запущена"
        }

    # === 2. Проверка статуса ===
    elif action == "status":
        if not client_job_id:
            return {"error": "Поле 'job_id' обязательно на верхнем уровне для action: status"}

        with store_lock:
            stored = results_store.get(client_job_id)

        if stored:
            base = {
                "job_id": client_job_id,
                "status": stored["status"],
                "progress": stored.get("progress", 0.0),
                "current_step": stored.get("current_step", 0),
                "total_steps": stored.get("total_steps", 0)
            }
            if stored["status"] == "failed":
                base["error"] = stored.get("error")
            return base

        # Запасной прогресс из Forge
        try:
            progress = requests.get(f"{API_URL}/sdapi/v1/progress?skip_current_image=false", timeout=10).json()
            return {
                "job_id": client_job_id,
                "status": "in_progress",
                "progress": progress.get("progress", 0.0),
                "eta_relative": progress.get("eta_relative"),
                "current_step": progress.get("state", {}).get("sampling_step", 0),
                "total_steps": progress.get("state", {}).get("sampling_steps", 0),
                "preview_image": progress.get("current_image")
            }
        except:
            return {"job_id": client_job_id, "status": "unknown", "message": "Задача не найдена"}

    # === 3. Получение результата ===
    elif action == "result":
        if not client_job_id:
            return {"error": "Поле 'job_id' обязательно на верхнем уровне для action: result"}

        with store_lock:
            stored = results_store.get(client_job_id)

        if not stored:
            return {"job_id": client_job_id, "status": "not_found", "error": "Результат не найден"}

        if stored["status"] == "completed":
            return {
                "job_id": client_job_id,
                "status": "completed",
                "images": stored["images"],
                "info": stored["info"],
                "parameters": stored.get("parameters", {})
            }
        elif stored["status"] == "failed":
            return {"job_id": client_job_id, "status": "failed", "error": stored.get("error")}
        else:
            return {"job_id": client_job_id, "status": stored["status"], "message": "Генерация в процессе"}

    else:
        return {"error": f"Неизвестное action: {action}. Доступно: generate, status, result"}

runpod.serverless.start({"handler": handler})