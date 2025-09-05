#!/bin/bash

# ===== BUILD CONFIGURATION =====
# Edit these variables to configure your Docker image build
INSTALL_N8N=false
INSTALL_NGROK=true
# ================================

# Build the free-render-server Docker image
echo "🚀 Building free-render-server Docker image..."
echo ""

echo "📦 Build configuration:"
echo "   • n8n installation: $INSTALL_N8N"
echo "   • ngrok installation: $INSTALL_NGROK"
echo "   • nginx: ✅ (always included)"
echo "   • SSH server: ✅ (always included)"
echo "   • Python 3.12: ✅ (always included)"
echo "   • GreyTHR Attendance System: ✅ (always included)"
echo ""

# Export variables for docker-compose
export INSTALL_N8N
export INSTALL_NGROK

# Build using docker-compose
echo "🔨 Starting Docker build..."
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
    echo "   • GreyTHR Attendance System: ✅ Available at /greythr"
    
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
    echo ""
    echo "💡 To change build options:"
    echo "   Edit the variables at the top of this script:"
    echo "   - INSTALL_N8N=true/false"
    echo "   - INSTALL_NGROK=true/false"
else
    echo ""
    echo "❌ Failed to build Docker image"
    exit 1
fi
