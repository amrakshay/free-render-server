#!/bin/bash

# Start SSH service
echo "Starting SSH service..."
/usr/sbin/sshd -D &

# Start nginx in the background as root
echo "Starting nginx..."
nginx -g "daemon off;" &

# Wait a moment for services to start
sleep 3

# Start ngrok if enabled
if [ "$NGROK_ENABLED" = "true" ]; then
    echo "Starting ngrok TCP tunnel for SSH..."
    if [ -n "$NGROK_AUTHTOKEN" ]; then
        ngrok authtoken "$NGROK_AUTHTOKEN"
    fi
    
    # Start ngrok for SSH (TCP port 22)
    ngrok tcp 22 --log=stdout --log-format=json &
    NGROK_PID=$!
    
    # Wait for ngrok to establish tunnel
    sleep 5
    
    # Extract tunnel URL and save to file
    echo "Extracting ngrok tunnel URL..."
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | jq -r '.tunnels[0].public_url' 2>/dev/null || echo "Failed to get ngrok URL")
    echo "SSH Tunnel: $NGROK_URL" | tee /var/www/ngrok.txt
    echo "Ngrok TCP tunnel started for SSH"
fi

# Start n8n if enabled
if [ "$N8N_ENABLED" = "true" ]; then
    echo "Starting n8n..."
    exec su-exec node n8n start
else
    echo "n8n is disabled (N8N_ENABLED=false)"
    echo "Services running: SSH, nginx"
    if [ "$NGROK_ENABLED" = "true" ]; then
        echo "Ngrok tunnel is active"
    fi
    echo "Container will keep running..."
    
    # Keep container alive without n8n
    tail -f /dev/null
fi
