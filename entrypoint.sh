#!/bin/bash
set -e

# 1️⃣ Скачиваем модели в /runpod-volume
python3 /workspace/download_models.py

# 2️⃣ Preload + запуск Forge API
python3 /workspace/launch.py
