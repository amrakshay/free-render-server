# Stage 1: Base image with expensive operations first
FROM alpine:latest AS base

# Build arguments for optional features
ARG INSTALL_N8N=false
ARG INSTALL_NGROK=true

# Install system dependencies (expensive but stable)
RUN apk update && apk add --no-cache \
    nginx \
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
    jq \
    chromium \
    chromium-chromedriver

# Conditionally install Node.js and npm for n8n
RUN if [ "$INSTALL_N8N" = "true" ]; then \
        apk add --no-cache nodejs npm; \
        echo "Node.js version: $(node --version)"; \
        echo "npm version: $(npm --version)"; \
    else \
        echo "Skipping Node.js/npm installation (INSTALL_N8N=false)"; \
    fi

# Verify Python 3.12 installation
RUN echo "Python version: $(python3 --version)" && \
    echo "Pip version: $(pip3 --version)" && \
    echo "Git version: $(git --version)"

# Install n8n globally FIRST (most expensive step) - only if enabled
RUN if [ "$INSTALL_N8N" = "true" ]; then \
        npm install -g n8n; \
        echo "n8n version: $(n8n --version)"; \
    else \
        echo "Skipping n8n installation (INSTALL_N8N=false)"; \
    fi

# Install ngrok (expensive but stable) - only if enabled
RUN if [ "$INSTALL_NGROK" = "true" ]; then \
        curl -sSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
        | tar xz -C /usr/local/bin; \
        echo "ngrok version: $(ngrok version)"; \
    else \
        echo "Skipping ngrok installation (INSTALL_NGROK=false)"; \
    fi

# Create node user (stable) - only if n8n is enabled
RUN if [ "$INSTALL_N8N" = "true" ]; then \
        addgroup -g 1000 node && \
        adduser -u 1000 -G node -s /bin/sh -D node; \
        echo "Created node user for n8n"; \
    else \
        echo "Skipping node user creation (INSTALL_N8N=false)"; \
    fi

# Configure SSH (stable)
RUN ssh-keygen -A && \
    mkdir -p /var/run/sshd && \
    echo 'root:Secure@FreeRender2024' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Stage 2: Final image with configuration
FROM base

# Build arguments need to be redeclared in new stage
ARG INSTALL_N8N=false
ARG INSTALL_NGROK=true

# Create necessary directories
RUN mkdir -p /var/log/nginx \
    && mkdir -p /run/nginx \
    && mkdir -p /var/cache/nginx \
    && mkdir -p /var/www

# Create n8n directories only if n8n is enabled
RUN if [ "$INSTALL_N8N" = "true" ]; then \
        mkdir -p /home/node/.n8n; \
        echo "Created n8n directories"; \
    else \
        echo "Skipping n8n directory creation (INSTALL_N8N=false)"; \
    fi

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY start_services.sh /start_services.sh
RUN chmod +x /start_services.sh

# Fix permissions
RUN chown -R nginx:nginx /var/log/nginx /var/cache/nginx /run/nginx

# Fix n8n permissions only if n8n is enabled
RUN if [ "$INSTALL_N8N" = "true" ]; then \
        chown -R node:node /home/node; \
        echo "Set n8n permissions"; \
    else \
        echo "Skipping n8n permission setup (INSTALL_N8N=false)"; \
    fi

# Set environment variables for n8n (only if enabled)
RUN if [ "$INSTALL_N8N" = "true" ]; then \
        echo "Setting n8n environment variables"; \
    else \
        echo "Skipping n8n environment variables (INSTALL_N8N=false)"; \
    fi

# n8n environment variables (will be ignored if n8n not installed)
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

# GreyTHR Attendance System environment variables
ENV GREYTHR_ENABLED=true
ENV GREYTHR_URL=
ENV GREYTHR_USERNAME=
ENV GREYTHR_PASSWORD=

# Copy GreyTHR Attendance System
COPY greythr-attendance-system /greythr-attendance-system
WORKDIR /greythr-attendance-system

# Setup GreyTHR environment using the existing setup script
RUN chmod +x server.sh && \
    ./server.sh setup

# Return to root directory
WORKDIR /

# Expose port 80 for nginx
EXPOSE 80

# Use the startup script
CMD ["/start_services.sh"]
