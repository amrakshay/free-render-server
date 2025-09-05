#!/bin/bash

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
REPO_URL="https://github.com/amrakshay/fastapi-todo-app.git"
WORK_DIR="$SCRIPT_DIR"
PROJECT_DIR="$WORK_DIR/fastapi-todo-app"
VENV_DIR="$PROJECT_DIR/venv"
APP_PORT=8000
PID_FILE="$SCRIPT_DIR/ruvicorn.pid"
LOG_FILE="$SCRIPT_DIR/fastapi_uvicorn.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if app is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    else
        return 1
    fi
}

# Check for required tools
check_prerequisites() {
    local missing_tools=()
    
    if ! command_exists git; then
        missing_tools+=("git")
    fi
    
    if ! command_exists python3; then
        missing_tools+=("python3")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
}

# Main deployment function
deploy_app() {
    log_info "Starting FastAPI Server deployment..."

    # Step 1: Create workdir and clone repository
    log_info "Setting up work directory: $WORK_DIR"
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"

    if [ -d "$PROJECT_DIR" ]; then
        log_warning "Project directory already exists. Removing and re-cloning..."
        rm -rf "$PROJECT_DIR"
    fi

    log_info "Cloning repository: $REPO_URL"
    if ! git clone "$REPO_URL"; then
        log_error "Failed to clone repository"
        exit 1
    fi

    # Step 2: Navigate to project directory
    cd "$PROJECT_DIR"
    log_success "Successfully cloned repository"

    # Step 3: Fetch latest main branch
    log_info "Fetching latest changes from main branch..."
    git fetch origin
    git checkout main
    git pull origin main
    log_success "Updated to latest main branch"

    # Step 4: Check for requirements.txt
    log_info "Checking for requirements.txt file..."
    if [ ! -f "requirements.txt" ]; then
        log_error "requirements.txt file not found in project directory"
        exit 1
    fi
    log_success "Found requirements.txt file"

    # Step 5: Check if Python3 is available
    if ! command_exists python3; then
        log_error "python3 is not installed or not in PATH"
        exit 1
    fi
    
    # Log Python version
    log_info "Using Python version: $(python3 --version)"

    # Step 6: Create virtual environment
    log_info "Creating virtual environment: $VENV_DIR"
    if [ -d "$VENV_DIR" ]; then
        log_warning "Virtual environment already exists. Removing and recreating..."
        rm -rf "$VENV_DIR"
    fi

    python3 -m venv "$VENV_DIR"
    log_success "Virtual environment created"

    # Step 7: Activate virtual environment
    log_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    
    # Upgrade pip
    pip install --upgrade pip

    # Install requirements
    log_info "Installing Python dependencies..."
    pip install -r requirements.txt
    log_success "Dependencies installed"

    # Step 8: Check for alembic directory and run migrations
    if [ -d "alembic" ]; then
        log_info "Found alembic directory. Running database migrations..."
        
        # Check if alembic is installed
        if ! command_exists alembic && ! python3 -c "import alembic" 2>/dev/null; then
            log_warning "Alembic not found in requirements. Installing alembic..."
            pip install alembic
        fi
        
        # Run migrations
        if python3 -m alembic upgrade head; then
            log_success "Database migrations completed successfully"
        else
            log_error "Database migrations failed"
            exit 1
        fi
    else
        log_warning "No alembic directory found. Skipping database migrations."
    fi

    # Step 9: Check for main.py (FastAPI app)
    if [ ! -f "main.py" ]; then
        log_error "main.py file not found. Cannot start FastAPI application."
        exit 1
    fi

    # Step 10: Install uvicorn if not present
    if ! command_exists uvicorn && ! python3 -c "import uvicorn" 2>/dev/null; then
        log_info "Installing uvicorn..."
        pip install uvicorn
    fi

    # Step 11: Start the FastAPI application
    log_info "Starting FastAPI Server on port $APP_PORT..."
    
    # Check if port is already in use
    if lsof -Pi :$APP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warning "Port $APP_PORT is already in use. Killing existing processes..."
        pkill -f "uvicorn.*:$APP_PORT" || true
        sleep 2
    fi

    # Start uvicorn in background
    nohup uvicorn main:app --host 0.0.0.0 --port $APP_PORT > "$LOG_FILE" 2>&1 &
    UVICORN_PID=$!

    # Wait a moment and check if the process is still running
    sleep 3
    if kill -0 $UVICORN_PID 2>/dev/null; then
        log_success "FastAPI Server started successfully!"
        log_info "PID: $UVICORN_PID"
        log_info "Application URL: http://0.0.0.0:$APP_PORT"
        log_info "Logs: tail -f $LOG_FILE"
        
        # Save PID for later management
        echo $UVICORN_PID > "$PID_FILE"
        
        echo ""
        echo "🚀 FastAPI Server deployment completed!"
        echo "📍 Application running at: http://localhost:$APP_PORT"
        echo "📋 Management commands:"
        echo "   View logs: $0 logs -f"
        echo "   Stop app: $0 stop"
        echo "   Restart: $0 restart"
        
    else
        log_error "Failed to start FastAPI Server"
        log_info "Check logs: cat $LOG_FILE"
        exit 1
    fi
}

# Start the application
start_app() {
    if is_running; then
        log_warning "FastAPI Server is already running (PID: $(cat $PID_FILE))"
        return 0
    fi
    
    log_info "Starting FastAPI Server deployment..."
    check_prerequisites
    deploy_app
}

# Stop the application
stop_app() {
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_info "Stopping FastAPI Server (PID: $PID)..."
        kill "$PID"
        rm -f "$PID_FILE"
        log_success "FastAPI Server stopped"
    else
        log_warning "FastAPI Server is not running"
    fi
}

# Restart the application
restart_app() {
    log_info "Restarting FastAPI Server..."
    stop_app
    sleep 2
    start_app
}

# Show application status
status_app() {
    echo "🔍 FastAPI Server Status"
    echo "===================================="
    
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_success "FastAPI Server is running (PID: $PID)"
        echo "📍 URL: http://localhost:$APP_PORT"
        echo "📋 Port: $APP_PORT"
        echo "📁 Logs: $LOG_FILE"
        echo "📁 PID file: $PID_FILE"
        echo "📁 Project: $PROJECT_DIR"
        
        if [ -f "$LOG_FILE" ]; then
            echo ""
            echo "📄 Recent logs (last 5 lines):"
            tail -5 "$LOG_FILE"
        fi
    else
        log_warning "FastAPI Server is not running"
    fi
}

# View logs
logs_app() {
    if [ -f "$LOG_FILE" ]; then
        if [ "$1" = "-f" ]; then
            log_info "Following logs (Ctrl+C to exit)..."
            tail -f "$LOG_FILE"
        else
            log_info "Recent logs:"
            tail -20 "$LOG_FILE"
        fi
    else
        log_error "Log file not found: $LOG_FILE"
    fi
}

# Show help
show_help() {
    echo "🚀 FastAPI Server Manager"
    echo "===================================="
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy and start the server from GitHub"
    echo "  start     Same as deploy"
    echo "  stop      Stop the running server"
    echo "  restart   Restart the server"
    echo "  status    Show server status"
    echo "  logs      Show recent logs"
    echo "  logs -f   Follow logs in real-time"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy         # Deploy and start server"
    echo "  $0 status         # Check if server is running"
    echo "  $0 logs -f        # Follow logs"
    echo "  $0 restart        # Restart the server"
    echo ""
    echo "Configuration:"
    echo "  Repository: $REPO_URL"
    echo "  Work Directory: $WORK_DIR"
    echo "  Port: $APP_PORT"
    echo "  Log File: $LOG_FILE"
}

# Cleanup function
cleanup() {
    if [ "$CLEANUP_ON_EXIT" = "true" ]; then
        log_info "Cleaning up on exit..."
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if kill -0 $PID 2>/dev/null; then
                log_info "Stopping server process (PID: $PID)..."
                kill $PID
            fi
        fi
    fi
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Main execution
main() {
    case "$1" in
        deploy|start)
            start_app
            ;;
        stop)
            stop_app
            ;;
        restart)
            restart_app
            ;;
        status)
            status_app
            ;;
        logs)
            logs_app "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            status_app
            echo ""
            echo "💡 Use '$0 help' for available commands"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for available commands"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
