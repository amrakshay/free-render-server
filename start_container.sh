#!/bin/bash

# Start the free-render-server container
echo "Starting free-render-server container..."

# Check if container exists (running or stopped)
if docker ps -a | grep -q "free-render-server-container"; then
    echo "⚠️  Container 'free-render-server-container' already exists"
    echo "Removing existing container..."
    docker stop free-render-server-container 2>/dev/null || true
    docker rm free-render-server-container
fi

# Start the container
docker run -d \
    --name free-render-server-container \
    -p 80:80 \
    free-render-server

if [ $? -eq 0 ]; then
    echo "✅ Container 'free-render-server-container' started successfully!"
    echo "🌐 Access n8n at: http://localhost/n8n"
    echo "💚 Health check at: http://localhost/health"
    echo ""
    echo "📋 To view logs: docker logs -f free-render-server-container"
    echo "🛑 To stop: docker stop free-render-server-container"
else
    echo "❌ Failed to start container"
    exit 1
fi
