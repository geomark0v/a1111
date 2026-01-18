# install_custom_nodes.py
"""
Установка custom nodes для ComfyUI из списка репозиториев.
Запускается как: python install_custom_nodes.py
"""

import os
import subprocess
import sys
from pathlib import Path

# Путь к папке custom_nodes
CUSTOM_NODES_DIR = Path("/workspace/comfyui/custom_nodes")
CUSTOM_NODES_DIR.mkdir(parents=True, exist_ok=True)

# Список репозиториев (в том же порядке, что у тебя)
REPOS = [
    "https://github.com/ltdrdata/ComfyUI-Manager.git",
    "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git",
    "https://github.com/kijai/ComfyUI-KJNodes.git",
    "https://github.com/rgthree/rgthree-comfy.git",
    # "https://github.com/JPS-GER/ComfyUI_JPS-Nodes.git",
    "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes.git",
    # "https://github.com/Jordach/comfy-plasma.git",
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git",
    "https://github.com/ClownsharkBatwing/RES4LYF.git",
    # "https://github.com/yolain/ComfyUI-Easy-Use.git",
    # "https://github.com/WASasquatch/was-node-suite-comfyui.git",
    # "https://github.com/theUpsider/ComfyUI-Logic.git",
    "https://github.com/cubiq/ComfyUI_essentials.git",
    "https://github.com/chrisgoringe/cg-image-picker.git",
    "https://github.com/chflame163/ComfyUI_LayerStyle.git",
    "https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git",
    # "https://github.com/Jonseed/ComfyUI-Detail-Daemon.git",
    # "https://github.com/shadowcz007/workspace/comfyui-mixlab-nodes.git",
    # "https://github.com/chflame163/ComfyUI_LayerStyle_Advance.git",
    # "https://github.com/bash-j/mikey_nodes.git",
    # "https://github.com/chrisgoringe/cg-use-everywhere.git",
    # "https://github.com/M1kep/CfyLiterals.gitom",
    "https://github.com/jerrywap/ComfyUI_LoadImageFromHttpURL.git",
    "https://codeberg.org/Gourieff/comfyui-reactor-node.git",
    "https://github.com/RikkOmsk/ComfyUI-S3-R2-Tools.git",
    "https://github.com/cubiq/ComfyUI_IPAdapter_plus.git",
    "https://github.com/ZHO-ZHO-ZHO/ComfyUI-InstantID.git",
]

def run_command(cmd, cwd=None, check=True):
    """Запуск команды и вывод результата"""
    print(f"+ {' '.join(cmd)}")
    try:
        subprocess.run(cmd, cwd=cwd, check=check, text=True)
    except subprocess.CalledProcessError as e:
        print(f"Ошибка при выполнении: {e}")
        # Не прерываем весь процесс, продолжаем дальше

def install_repo(repo_url):
    repo_name = Path(repo_url).stem  # имя без .git
    repo_path = CUSTOM_NODES_DIR / repo_name

    if repo_path.exists():
        print(f"[SKIP] {repo_name} уже существует")
        return repo_path

    print(f"[CLONE] {repo_url}")

    # Особый случай для UltimateSDUpscale — с --recursive
    if repo_url == "https://github.com/ssitu/ComfyUI_UltimateSDUpscale.git":
        run_command(["git", "clone", "--recursive", repo_url, str(repo_path)])
    else:
        run_command(["git", "clone", repo_url, str(repo_path)])

    # Установка requirements.txt
    reqs_path = repo_path / "requirements.txt"
    if reqs_path.exists():
        print(f"[INSTALL] requirements.txt для {repo_name}")
        run_command([sys.executable, "-m", "/workspace/venv/bin/pip", "install", "-r", str(reqs_path)])

    # Запуск install.py, если есть
    install_py = repo_path / "install.py"
    if install_py.exists():
        print(f"[RUN] install.py для {repo_name}")
        run_command([sys.executable, str(install_py)], cwd=repo_path)

    # Специальная проверка для ReActor
    if repo_name == "comfyui-reactor-node":
        print("\n[ReActor] Проверка установки...")
        reactor_dir = Path("/root/.reactor")
        reactor_dir.mkdir(parents=True, exist_ok=True)

        print("Папка ReActor:", repo_path)
        print("Первые 10 .py файлов:")
        for py_file in list(repo_path.rglob("*.py"))[:10]:
            print(f"  - {py_file}")

        print("\nПроверка импорта reactor...")
        try:
            run_command([
                sys.executable, "-c",
                f"import sys; sys.path.append('{repo_path}'); import reactor; print('ReActor OK')"
            ], check=False)
        except:
            print("ReActor import failed")

    return repo_path

def main():
    print("=== Установка custom nodes ===")
    os.chdir(CUSTOM_NODES_DIR)

    for repo_url in REPOS:
        if repo_url.strip().startswith("#"):
            print(f"[COMMENT] Пропуск закомментированной строки: {repo_url}")
            continue
        install_repo(repo_url.strip())

    print("\n=== Установка завершена ===")

if __name__ == "__main__":
    main()