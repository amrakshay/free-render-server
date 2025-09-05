#!/bin/bash

# Start the free-render-server container using docker-compose
echo "Starting free-render-server container..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found. Creating from template..."
    cp env.example .env
    echo "📝 Please edit .env file to configure ngrok if needed"
fi

# Stop any existing containers
echo "🔄 Stopping any existing containers..."
docker-compose down

# Start the services
echo "🚀 Starting services with docker-compose..."
docker-compose up -d

if [ $? -eq 0 ]; then
    echo "✅ Container 'free-render-server-container' started successfully!"
    echo ""
    echo "🌐 Available Services:"
    echo "   n8n workflow automation: http://localhost/n8n"
    echo "   Health check: http://localhost/health"
    
    # Check if GreyTHR is enabled
    if grep -q "GREYTHR_ENABLED=false" .env 2>/dev/null; then
        echo "   GreyTHR: ❌ Disabled (enable with GREYTHR_ENABLED=true)"
    else
        echo "   GreyTHR Attendance System: http://localhost/greythr"
        echo "   GreyTHR API endpoints:"
        echo "     - POST http://localhost/greythr/signin"
        echo "     - POST http://localhost/greythr/signout"
    fi
    
    # Check if ngrok is enabled
    if grep -q "NGROK_ENABLED=true" .env 2>/dev/null; then
        echo "   SSH tunnel: Available via ngrok"
        echo "   📋 Check ngrok URL: docker-compose logs | grep 'SSH Tunnel'"
    else
        echo "   SSH tunnel: ❌ Disabled (enable with NGROK_ENABLED=true)"
    fi
    
    echo ""
    echo "📋 To view logs: docker-compose logs -f"
    echo "🛑 To stop: docker-compose down"
    echo "🔧 To edit config: edit .env file and restart"
else
    echo "❌ Failed to start container"
    exit 1
fi
