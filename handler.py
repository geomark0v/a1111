import runpod
import requests
import subprocess
import time
import os

# Путь к Forge в volume
FORGE_DIR = "/runpod-volume/stable-diffusion-webui-forge"
LAUNCH_PY = os.path.join(FORGE_DIR, "launch.py")
API_URL = "http://127.0.0.1:8080"

def start_forge():
    print("[INFO] Starting Forge...")

    cmd = [
        "python3", LAUNCH_PY,
        "--listen",
        "--port", "8080",
        "--api",
        "--skip-version-check",
        "--no-download-sd-model",
        "--skip-python-version-check",
        "--skip-install",
        "--no-hashing",
        "--no-half-vae",
        "--opt-sdp-no-mem-attention",
        "--xformers",
        "--nowebui"
    ]

    subprocess.run(cmd, check=True)

def wait_for_api(timeout=300):
    print("[INFO] Waiting for Forge API...")
    for _ in range(timeout):
        try:
            resp = requests.get(f"{API_URL}/sdapi/v1/sd-models", timeout=10)
            if resp.status_code == 200:
                print("[INFO] Forge API ready!")
                return
        except:
            time.sleep(1)
    raise TimeoutError("Forge API timeout")

# Маппинг action → (path, method)
ACTION_MAPPING = {
    "txt2img": ("/sdapi/v1/txt2img", "POST"),
    "img2img": ("/sdapi/v1/img2img", "POST"),
    "extra-single-image": ("/sdapi/v1/extra-single-image", "POST"),
    "extra-batch-images": ("/sdapi/v1/extra-batch-images", "POST"),
    "png-info": ("/sdapi/v1/png-info", "POST"),
    "progress": ("/sdapi/v1/progress", "GET"),
    "interrogate": ("/sdapi/v1/interrogate", "POST"),
    "interrupt": ("/sdapi/v1/interrupt", "POST"),
    "skip": ("/sdapi/v1/skip", "POST"),
    "options-get": ("/sdapi/v1/options", "GET"),
    "options-set": ("/sdapi/v1/options", "POST"),
    "cmd-flags": ("/sdapi/v1/cmd-flags", "GET"),
    "samplers": ("/sdapi/v1/samplers", "GET"),
    "schedulers": ("/sdapi/v1/schedulers", "GET"),
    "upscalers": ("/sdapi/v1/upscalers", "GET"),
    "latent-upscale-modes": ("/sdapi/v1/latent-upscale-modes", "GET"),
    "sd-models": ("/sdapi/v1/sd-models", "GET"),
    "sd-modules": ("/sdapi/v1/sd-modules", "GET"),
    "hypernetworks": ("/sdapi/v1/hypernetworks", "GET"),
    "face-restorers": ("/sdapi/v1/face-restorers", "GET"),
    "realesrgan-models": ("/sdapi/v1/realesrgan-models", "GET"),
    "prompt-styles": ("/sdapi/v1/prompt-styles", "GET"),
    "embeddings": ("/sdapi/v1/embeddings", "GET"),
    "refresh-embeddings": ("/sdapi/v1/refresh-embeddings", "POST"),
    "refresh-checkpoints": ("/sdapi/v1/refresh-checkpoints", "POST"),
    "refresh-vae": ("/sdapi/v1/refresh-vae", "POST"),
    "create-embedding": ("/sdapi/v1/create/embedding", "POST"),
    "create-hypernetwork": ("/sdapi/v1/create/hypernetwork", "POST"),
    "memory": ("/sdapi/v1/memory", "GET"),
    "unload-checkpoint": ("/sdapi/v1/unload-checkpoint", "POST"),
    "reload-checkpoint": ("/sdapi/v1/reload-checkpoint", "POST"),
    "scripts": ("/sdapi/v1/scripts", "GET"),
    "script-info": ("/sdapi/v1/script-info", "GET"),
    "extensions": ("/sdapi/v1/extensions", "GET")
}

def handler(job):
    request = job.get("input", {})
    action = request.get("action")
    payload = request.get("input", {})

    if not action or action not in ACTION_MAPPING:
        return {"error": f"Invalid or unsupported action: {action}. Available: {', '.join(ACTION_MAPPING.keys())}"}

    path, method = ACTION_MAPPING[action]
    url = API_URL + path

    try:
        if method == "GET":
            resp = requests.get(url, timeout=600)
        else:  # POST
            resp = requests.post(url, json=payload, timeout=600)

        resp.raise_for_status()

        try:
            return resp.json()
        except ValueError:
            return {"text": resp.text, "status_code": resp.status_code}

    except requests.exceptions.Timeout:
        return {"error": "Forge API timeout (600s)"}
    except requests.exceptions.ConnectionError:
        return {"error": "Cannot connect to Forge API"}
    except requests.exceptions.HTTPError as e:
        return {"error": f"Forge error {resp.status_code}: {resp.text}"}
    except Exception as e:
        return {"error": f"Unexpected error: {str(e)}"}

if __name__ == "__main__":
    wait_for_api()
    runpod.serverless.start({"handler": handler})