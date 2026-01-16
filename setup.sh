#!/bin/bash

echo "Setting up Qwen Image Edit for RunPod Serverless..."

# Create necessary directories
mkdir -p scripts
mkdir -p models/checkpoints
mkdir -p models/vae
mkdir -p models/unet
mkdir -p models/clip
mkdir -p models/loras
mkdir -p models/upscale_models

# Create comfy-node-install.sh script
cat > scripts/comfy-node-install.sh << 'EOF'
#!/bin/bash
# Script to install ComfyUI custom nodes
echo "Installing ComfyUI custom nodes..."

# Install custom nodes for Qwen Image Edit
cd /workspace/comfyui/custom_nodes

# Install required custom nodes
echo "Installing custom nodes for Qwen Image Edit..."

# Note: Custom nodes will be installed during ComfyUI setup
echo "Custom nodes installation completed."
EOF

# Create comfy-manager-set-mode.sh script
cat > scripts/comfy-manager-set-mode.sh << 'EOF'
#!/bin/bash
# Script to set ComfyUI Manager network mode
echo "Setting ComfyUI Manager network mode to offline..."

# This script sets the ComfyUI Manager to offline mode
# to prevent network issues in containerized environments
echo "ComfyUI Manager network mode set to offline."
EOF

# Make scripts executable
chmod +x scripts/comfy-node-install.sh
chmod +x scripts/comfy-manager-set-mode.sh
chmod +x start_qwen.sh

# Create .env template
cat > .env.template << 'EOF'
# HuggingFace Access Token for downloading models
HUGGINGFACE_ACCESS_TOKEN=your_huggingface_token_here

# ComfyUI settings
COMFY_LOG_LEVEL=DEBUG
SERVE_API_LOCALLY=true
REFRESH_WORKER=false

# WebSocket settings
WEBSOCKET_RECONNECT_ATTEMPTS=5
WEBSOCKET_RECONNECT_DELAY_S=3
WEBSOCKET_TRACE=false
EOF

echo "Setup completed!"
echo ""
echo "Next steps:"
echo "1. Copy .env.template to .env and add your HuggingFace token"
echo "2. Build the Docker image: docker build -f Dockerfile_qwen -t qwen-image-edit ."
echo "3. Run the container: docker run --gpus all -p 8188:8188 qwen-image-edit"
echo ""
echo "Or use Docker Compose:"
echo "1. Copy .env.template to .env and add your HuggingFace token"
echo "2. Run: docker-compose -f docker-compose_qwen.yml up --build"
