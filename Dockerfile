# Stage 1: Base image with expensive operations first
FROM alpine:latest AS base

# Install system dependencies (expensive but stable)
RUN apk update && apk add --no-cache \
    nginx \
    nodejs \
    npm \
    python3 \
    python3-dev \
    py3-pip \
    git \
    su-exec \
    shadow \
    bash \
    curl \
    unzip \
    openssh \
    jq

# Verify Python 3.12 installation
RUN echo "Python version: $(python3 --version)" && \
    echo "Pip version: $(pip3 --version)" && \
    echo "Git version: $(git --version)"

# Install n8n globally FIRST (most expensive step)
RUN npm install -g n8n

# Install ngrok (expensive but stable)
RUN curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
    | tar xz -C /usr/local/bin

# Create node user (stable)
RUN addgroup -g 1000 node && \
    adduser -u 1000 -G node -s /bin/sh -D node

# Configure SSH (stable)
RUN ssh-keygen -A && \
    mkdir -p /var/run/sshd && \
    echo 'root:Secure@FreeRender2024' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Stage 2: Final image with configuration
FROM base

# Create necessary directories
RUN mkdir -p /var/log/nginx \
    && mkdir -p /run/nginx \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /home/node/.n8n \
    && mkdir -p /var/www

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY start_services.sh /start_services.sh
RUN chmod +x /start_services.sh

# Fix permissions
RUN chown -R nginx:nginx /var/log/nginx /var/cache/nginx /run/nginx && \
    chown -R node:node /home/node

# Set environment variables for n8n
ENV N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=http
ENV N8N_PATH=/n8n/
ENV N8N_DIAGNOSTICS_ENABLED=false
ENV N8N_ANONYMOUS_USAGE=false
ENV N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true

# Set environment variables for optional services
ENV N8N_ENABLED=false
ENV NGROK_ENABLED=false
ENV NGROK_AUTHTOKEN=

# Expose port 80 for nginx
EXPOSE 80

# Use the startup script
CMD ["/start_services.sh"]
