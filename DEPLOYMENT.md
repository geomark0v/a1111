# Развертывание Qwen Image Edit на RunPod Serverless

## Обзор

Этот проект адаптирует Qwen Image Edit для работы с RunPod Serverless, используя ComfyUI в качестве движка генерации изображений.

## Файлы проекта

### Основные файлы:
- `Dockerfile_qwen` - Docker образ для Qwen Image Edit
- `handler_qwen.py` - RunPod Serverless handler
- `start_qwen.sh` - Скрипт запуска
- `requirements_qwen.txt` - Python зависимости
- `docker-compose_qwen.yml` - Docker Compose конфигурация

### Вспомогательные файлы:
- `test_input_qwen.json` - Тестовый входной файл
- `README_qwen.md` - Документация
- `setup_qwen.sh` - Скрипт настройки

## Быстрый старт

### 1. Настройка окружения

```bash
# Клонирование и настройка
git clone <repository-url>
cd SwapifyStudio

# Запуск скрипта настройки
./setup_qwen.sh

# Настройка переменных окружения
cp .env.template .env
# Отредактируйте .env и добавьте ваш HuggingFace токен
```

### 2. Локальное тестирование

```bash
# Сборка образа
docker build -f Dockerfile_qwen -t qwen-image-edit:latest \
  --build-arg HUGGINGFACE_ACCESS_TOKEN=your_token_here .

# Запуск контейнера
docker run --gpus all -p 8188:8188 qwen-image-edit:latest
```

### 3. Развертывание на RunPod

#### Шаг 1: Подготовка образа

```bash
# Сборка образа с тегом для RunPod Registry
docker build -f Dockerfile_qwen -t runpod/qwen-image-edit:latest \
  --build-arg HUGGINGFACE_ACCESS_TOKEN=your_token_here .

# Вход в RunPod Registry
docker login registry.runpod.io

# Загрузка образа в RunPod Registry
docker tag runpod/qwen-image-edit:latest registry.runpod.io/your-username/qwen-image-edit:latest
docker push registry.runpod.io/your-username/qwen-image-edit:latest
```

#### Шаг 2: Создание Serverless Endpoint

1. Войдите в RunPod Console
2. Перейдите в раздел "Serverless"
3. Нажмите "New Endpoint"
4. Заполните параметры:
   - **Name**: `qwen-image-edit`
   - **Container Image**: `registry.runpod.io/your-username/qwen-image-edit:latest`
   - **Container Start Command**: `/start_qwen.sh`
   - **Max Workers**: `1`
   - **Idle Timeout**: `30`
   - **Max Execution Time**: `300`

#### Шаг 3: Настройка переменных окружения

В настройках endpoint добавьте:
```
COMFY_LOG_LEVEL=INFO
SERVE_API_LOCALLY=true
REFRESH_WORKER=false
WEBSOCKET_RECONNECT_ATTEMPTS=5
WEBSOCKET_RECONNECT_DELAY_S=3
WEBSOCKET_TRACE=false
```

## Использование API

### Базовый запрос

```python
import requests
import json

# URL вашего RunPod endpoint
endpoint_url = "https://api.runpod.ai/v2/your-endpoint-id/runsync"

# Загрузка workflow
with open('workflows/Qwen_image_edit.json', 'r') as f:
    workflow = json.load(f)

# Подготовка запроса
payload = {
    "input": {
        "workflow": workflow,
        "images": []  # Добавьте изображения если нужно
    }
}

# Отправка запроса
response = requests.post(
    endpoint_url,
    headers={
        "Authorization": f"Bearer {your_runpod_api_key}",
        "Content-Type": "application/json"
    },
    json=payload
)

result = response.json()
print(f"Status: {result['status']}")
if 'output' in result:
    print(f"Images generated: {len(result['output'].get('images', []))}")
```

### Загрузка изображений

```python
import base64
from PIL import Image
import io

def image_to_base64(image_path):
    with open(image_path, "rb") as image_file:
        return base64.b64encode(image_file.read()).decode('utf-8')

# Добавление изображений в запрос
images = [
    {
        "name": "input_image.png",
        "image": image_to_base64("path/to/your/image.png")
    }
]

payload = {
    "input": {
        "workflow": workflow,
        "images": images
    }
}
```

## Мониторинг и отладка

### Логи контейнера

```bash
# Просмотр логов локального контейнера
docker logs <container_id>

# Просмотр логов в RunPod Console
# Перейдите в раздел "Serverless" -> ваш endpoint -> "Logs"
```

### Проверка статуса

```python
# Проверка статуса endpoint
status_url = "https://api.runpod.ai/v2/your-endpoint-id/status"
response = requests.get(
    status_url,
    headers={"Authorization": f"Bearer {your_runpod_api_key}"}
)
print(response.json())
```

## Оптимизация производительности

### Настройки GPU

- **Минимальные требования**: RTX 3080 или эквивалент
- **Рекомендуемые**: RTX 4090 или A100
- **VRAM**: Минимум 12GB, рекомендуется 24GB+

### Настройки контейнера

```yaml
# В docker-compose_qwen.yml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
    limits:
      memory: 32G
      cpus: '8.0'
```

## Устранение неполадок

### Частые проблемы

1. **Ошибка загрузки моделей**
   - Проверьте HuggingFace токен
   - Убедитесь в доступности интернета
   - Проверьте размер доступного места

2. **Ошибки GPU**
   - Убедитесь в поддержке CUDA
   - Проверьте драйверы NVIDIA
   - Увеличьте лимиты памяти

3. **Таймауты**
   - Увеличьте `Max Execution Time`
   - Оптимизируйте workflow
   - Используйте меньшие модели

### Логи для отладки

```bash
# Включение подробных логов
export COMFY_LOG_LEVEL=DEBUG
export WEBSOCKET_TRACE=true
```

## Безопасность

### Переменные окружения

- Никогда не коммитьте `.env` файл
- Используйте секреты RunPod для токенов
- Регулярно обновляйте токены доступа

### Сетевая безопасность

- Используйте HTTPS для всех запросов
- Ограничьте доступ к endpoint
- Мониторьте использование API

## Масштабирование

### Горизонтальное масштабирование

- Увеличьте `Max Workers` в настройках endpoint
- Используйте балансировщик нагрузки
- Мониторьте использование ресурсов

### Вертикальное масштабирование

- Увеличьте лимиты памяти и CPU
- Используйте более мощные GPU
- Оптимизируйте workflow

## Поддержка

- GitHub Issues для багов и предложений
- RunPod Discord для технической поддержки
- Документация ComfyUI для workflow вопросов
