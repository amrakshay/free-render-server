#!/bin/bash

# Start nginx in the background as root
echo "Starting nginx..."
nginx -g "daemon off;" &

# Wait a moment for nginx to start
sleep 2

# Start n8n in the foreground as node user
echo "Starting n8n..."
exec su-exec node n8n start
