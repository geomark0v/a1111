#!/bin/bash
# Script to set ComfyUI Manager network mode
echo "Setting ComfyUI Manager network mode to $1..."

MODE="${1:-offline}"
CONFIG_DIR="/comfyui/user/__manager"
CONFIG_FILE="$CONFIG_DIR/config.ini"

# Создаём директорию если не существует
mkdir -p "$CONFIG_DIR"

# Создаём или обновляем конфиг
if [ -f "$CONFIG_FILE" ]; then
    # Обновляем существующий конфиг
    if grep -q "network_mode" "$CONFIG_FILE"; then
        sed -i "s/network_mode.*/network_mode = $MODE/" "$CONFIG_FILE"
    else
        echo "network_mode = $MODE" >> "$CONFIG_FILE"
    fi
else
    # Создаём новый конфиг
    cat > "$CONFIG_FILE" << EOF
[default]
network_mode = $MODE
update_check = false
EOF
fi

echo "ComfyUI Manager network mode set to $MODE."
