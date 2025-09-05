#!/bin/bash

# Build the free-render-server Docker image with optional features
echo "🚀 Building free-render-server Docker image..."
echo ""

# Show build options
echo "📋 Available build configurations:"
echo "   1. Minimal build (default): nginx + SSH + Python only"
echo "   2. Full build: n8n + ngrok + nginx + SSH + Python"
echo "   3. No ngrok: n8n + nginx + SSH + Python"
echo "   4. Custom build: specify your own options"
echo ""

# Get user choice
read -p "Choose build type [1-4] or press Enter for default (1): " choice

case "$choice" in
    "2")
        echo "🔧 Building full image (n8n + ngrok + nginx + SSH + Python)..."
        export INSTALL_N8N=true
        export INSTALL_NGROK=true
        ;;
    "3")
        echo "🔧 Building without ngrok..."
        export INSTALL_N8N=true
        export INSTALL_NGROK=false
        ;;
    "4")
        echo "🔧 Custom build options:"
        read -p "Install n8n? [y/N]: " install_n8n
        read -p "Install ngrok? [y/N]: " install_ngrok
        
        export INSTALL_N8N=$([ "$install_n8n" = "y" ] && echo "true" || echo "false")
        export INSTALL_NGROK=$([ "$install_ngrok" = "y" ] && echo "true" || echo "false")
        ;;
    *)
        echo "🔧 Building minimal image (default: nginx + SSH + Python only)..."
        export INSTALL_N8N=false
        export INSTALL_NGROK=false
        ;;
esac

echo ""
echo "📦 Build configuration:"
echo "   • n8n installation: $INSTALL_N8N"
echo "   • ngrok installation: $INSTALL_NGROK"
echo "   • nginx: ✅ (always included)"
echo "   • SSH server: ✅ (always included)"
echo "   • Python 3.12: ✅ (always included)"
echo ""

# Build using docker-compose
docker-compose build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Docker image 'free-render-server' built successfully!"
    echo ""
    echo "🎯 Image capabilities:"
    echo "   • Base OS: Alpine Linux"
    echo "   • Web server: nginx (port 80)"
    echo "   • SSH access: root/Secure@FreeRender2024"
    echo "   • Python: 3.12 with pip and git"
    
    if [ "$INSTALL_N8N" = "true" ]; then
        echo "   • Workflow automation: n8n (/n8n path)"
    else
        echo "   • n8n: ❌ Not installed"
    fi
    
    if [ "$INSTALL_NGROK" = "true" ]; then
        echo "   • SSH tunneling: ngrok (when enabled)"
    else
        echo "   • ngrok: ❌ Not installed"
    fi
    
    echo ""
    echo "🚀 Next step: ./start_container.sh"
else
    echo ""
    echo "❌ Failed to build Docker image"
    exit 1
fi
