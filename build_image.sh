#!/bin/bash

# Build the free-render-server Docker image
echo "Building free-render-server Docker image..."
docker build -t free-render-server .

if [ $? -eq 0 ]; then
    echo "✅ Docker image 'free-render-server' built successfully!"
else
    echo "❌ Failed to build Docker image"
    exit 1
fi
