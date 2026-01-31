#!/bin/bash
# Script to set ComfyUI Manager network mode
echo "Setting ComfyUI Manager network mode to $1..."

MODE="${1:-offline}"

# ComfyUI-Manager V3 использует разные пути для конфига
# Создаём конфиг во всех возможных местах
CONFIG_DIRS=(
    "/comfyui/user/default/ComfyUI-Manager"
    "/comfyui/user/__manager"
    "/comfyui/custom_nodes/ComfyUI-Manager"
)

for CONFIG_DIR in "${CONFIG_DIRS[@]}"; do
    CONFIG_FILE="$CONFIG_DIR/config.ini"
    mkdir -p "$CONFIG_DIR"
    
    cat > "$CONFIG_FILE" << EOF
[default]
network_mode = $MODE
update_check = false
skip_update = true
EOF
    echo "Created config at $CONFIG_FILE"
done

echo "ComfyUI Manager network mode set to $MODE."
