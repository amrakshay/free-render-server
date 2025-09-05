#!/bin/bash

set -e  # Exit on any error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROJECT_DIR="$SCRIPT_DIR"
VENV_DIR="$PROJECT_DIR/venv"
APP_PORT=5000
PID_FILE="$SCRIPT_DIR/flask_server.pid"
LOG_FILE="$SCRIPT_DIR/flask_server.log"
APP_FILE="$PROJECT_DIR/app.py"
PRODUCTION_MODE=false

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
    
    if ! command_exists python3; then
        missing_tools+=("python3")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        exit 1
    fi
}

# Setup virtual environment and dependencies
setup_environment() {
    log_info "Starting GreyTHR Attendance System setup..."

    # Step 1: Navigate to project directory
    cd "$PROJECT_DIR"
    log_info "Working in directory: $PROJECT_DIR"

    # Step 2: Check for app.py
    log_info "Checking for app.py file..."
    if [ ! -f "$APP_FILE" ]; then
        log_error "app.py file not found in project directory"
        log_info "Expected file: $APP_FILE"
        exit 1
    fi
    log_success "Found app.py file"

    # Step 3: Check for requirements.txt
    log_info "Checking for requirements.txt file..."
    if [ ! -f "requirements.txt" ]; then
        log_error "requirements.txt file not found in project directory"
        exit 1
    fi
    log_success "Found requirements.txt file"

    # Step 4: Check if Python3 is available
    if ! command_exists python3; then
        log_error "python3 is not installed or not in PATH"
        exit 1
    fi
    
    # Log Python version
    log_info "Using Python version: $(python3 --version)"

    # Step 5: Create virtual environment
    log_info "Creating virtual environment: $VENV_DIR"
    if [ -d "$VENV_DIR" ]; then
        log_warning "Virtual environment already exists. Removing and recreating..."
        rm -rf "$VENV_DIR"
    fi

    python3 -m venv "$VENV_DIR"
    log_success "Virtual environment created successfully"

    # Step 6: Activate virtual environment
    log_info "Activating virtual environment..."
    source "$VENV_DIR/bin/activate"
    log_success "Virtual environment activated"

    # Step 7: Upgrade pip
    log_info "Upgrading pip..."
    python -m pip install --upgrade pip
    log_success "Pip upgraded successfully"

    # Step 8: Install requirements
    log_info "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
    log_success "Dependencies installed successfully"

    log_success "Environment setup completed!"
}

# Start the Flask server
start_app() {
    log_info "Starting GreyTHR Attendance System server..."

    # Check if already running
    if is_running; then
        PID=$(cat "$PID_FILE")
        log_warning "Server is already running with PID: $PID"
        log_info "Use './server.sh stop' to stop it first, or './server.sh restart' to restart"
        return 1
    fi

    # Check if virtual environment exists
    if [ ! -d "$VENV_DIR" ]; then
        log_warning "Virtual environment not found. Setting up environment first..."
        setup_environment
    fi

    # Check if app file exists
    if [ ! -f "$APP_FILE" ]; then
        log_error "Flask app file not found: $APP_FILE"
        return 1
    fi

    # Navigate to project directory
    cd "$PROJECT_DIR"
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"

    # Start server in background
    if [ "$PRODUCTION_MODE" = "true" ]; then
        log_info "Starting Gunicorn production server on port $APP_PORT..."
        nohup gunicorn -w 1 -b 0.0.0.0:$APP_PORT app:app > "$LOG_FILE" 2>&1 &
    else
        log_info "Starting Flask development server on port $APP_PORT..."
        nohup python app.py > "$LOG_FILE" 2>&1 &
    fi
    
    # Save PID
    echo $! > "$PID_FILE"
    
    # Wait a moment and check if it started successfully
    sleep 3
    
    if is_running; then
        PID=$(cat "$PID_FILE")
        if [ "$PRODUCTION_MODE" = "true" ]; then
            log_success "GreyTHR Attendance System started successfully (Production Mode - Gunicorn)!"
        else
            log_success "GreyTHR Attendance System started successfully (Development Mode - Flask)!"
        fi
        log_info "Process ID: $PID"
        log_info "Port: $APP_PORT"
        log_info "Log file: $LOG_FILE"
        log_info "Web interface: http://localhost:$APP_PORT"
        log_info "Health check: http://localhost:$APP_PORT/health"
        echo
        log_info "Quick test commands:"
        log_info "  curl http://localhost:$APP_PORT/health"
        log_info "  curl http://localhost:$APP_PORT/api/employees"
        echo
        log_info "Management commands:"
        log_info "  ./server.sh status  - Check server status"
        log_info "  ./server.sh logs    - View server logs"
        log_info "  ./server.sh stop    - Stop the server"
    else
        log_error "Failed to start Flask server"
        log_info "Check the log file for details: $LOG_FILE"
        return 1
    fi
}

# Stop the Flask server
stop_app() {
    log_info "Stopping GreyTHR Attendance System server..."

    if ! is_running; then
        log_warning "Server is not running"
        return 0
    fi

    PID=$(cat "$PID_FILE")
    log_info "Terminating process with PID: $PID"
    
    # Try graceful shutdown first
    if kill "$PID" 2>/dev/null; then
        # Wait up to 10 seconds for graceful shutdown
        for i in {1..10}; do
            if ! kill -0 "$PID" 2>/dev/null; then
                break
            fi
            sleep 1
        done
        
        # Force kill if still running
        if kill -0 "$PID" 2>/dev/null; then
            log_warning "Graceful shutdown failed, forcing termination..."
            kill -9 "$PID" 2>/dev/null
        fi
    fi
    
    # Clean up PID file
    rm -f "$PID_FILE"
    
    log_success "GreyTHR Attendance System stopped successfully"
}

# Restart the Flask server
restart_app() {
    log_info "Restarting GreyTHR Attendance System server..."
    stop_app
    sleep 2
    start_app
}

# Show application status
status_app() {
    echo "🔍 GreyTHR Attendance System Status"
    echo "===================================="
    
    if is_running; then
        PID=$(cat "$PID_FILE")
        echo "Status: ✅ RUNNING"
        echo "Process ID: $PID"
        echo "Port: $APP_PORT"
        echo "Log file: $LOG_FILE"
        echo "Web interface: http://localhost:$APP_PORT"
        echo "Health check: http://localhost:$APP_PORT/health"
        
        # Show resource usage if possible
        if command_exists ps; then
            echo ""
            echo "Resource usage:"
            ps -p "$PID" -o pid,pcpu,pmem,etime,cmd 2>/dev/null || echo "Could not retrieve resource usage"
        fi
        
        # Test if server is responding
        echo ""
        echo "Health check:"
        if command_exists curl; then
            if curl -s -f "http://localhost:$APP_PORT/health" >/dev/null 2>&1; then
                echo "✅ Server is responding to HTTP requests"
            else
                echo "❌ Server is not responding to HTTP requests"
            fi
        else
            echo "ℹ️  Install curl to test HTTP health check"
        fi
    else
        echo "Status: ❌ NOT RUNNING"
        echo "Port: $APP_PORT (not in use)"
        
        if [ -f "$LOG_FILE" ]; then
            echo "Last log entries:"
            tail -n 5 "$LOG_FILE" 2>/dev/null || echo "Could not read log file"
        fi
    fi
    
    echo ""
    echo "Configuration:"
    echo "  Project directory: $PROJECT_DIR"
    echo "  Virtual environment: $VENV_DIR"
    echo "  App file: $APP_FILE"
    echo "  PID file: $PID_FILE"
    echo "  Log file: $LOG_FILE"
}

# Show recent logs
logs_app() {
    if [ ! -f "$LOG_FILE" ]; then
        log_warning "Log file not found: $LOG_FILE"
        return 1
    fi
    
    log_info "Showing recent logs from: $LOG_FILE"
    echo "=================================="
    tail -f "$LOG_FILE"
}

# Show help information
show_help() {
    echo "🚀 GreyTHR Attendance System Manager"
    echo ""
    echo "USAGE:"
    echo "  ./server.sh <command>"
    echo ""
    echo "COMMANDS:"
    echo "  setup          - Set up virtual environment and install dependencies"
    echo "  start          - Start Flask development server (includes setup if needed)"
    echo "  start-prod     - Start Gunicorn production server"
    echo "  production     - Alias for start-prod"
    echo "  stop           - Stop the server"
    echo "  restart        - Restart Flask development server"
    echo "  restart-prod   - Restart Gunicorn production server"
    echo "  status         - Show server status and configuration"
    echo "  logs           - Show and follow server logs"
    echo "  help           - Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  ./server.sh setup        # Set up environment"
    echo "  ./server.sh start        # Start development server"
    echo "  ./server.sh start-prod   # Start production server"
    echo "  ./server.sh status       # Check if running"
    echo "  ./server.sh logs         # View logs"
    echo "  ./server.sh stop         # Stop server"
    echo ""
    echo "API ENDPOINTS:"
    echo "  Root endpoint:  http://localhost:$APP_PORT/"
    echo "  Health Check:   http://localhost:$APP_PORT/health"
    echo "  Sign In:        POST http://localhost:$APP_PORT/signin"
    echo "  Sign Out:       POST http://localhost:$APP_PORT/signout"
    echo ""
    echo "SERVER MODES:"
    echo "  🔧 Development (start)      - Flask dev server with debug mode"
    echo "  🚀 Production (start-prod)  - Gunicorn WSGI server for performance"
    echo ""
    echo "FEATURES:"
    echo "  ✅ Simple attendance API (4 endpoints)"
    echo "  ✅ GreyTHR API integration for real attendance marking"
    echo "  ✅ Local record keeping with fallback"
    echo "  ✅ JSON-only responses (no web interface)"
    echo "  ✅ Comprehensive error handling and logging"
    echo "  ✅ Environment variable configuration"
    echo ""
    echo "ENVIRONMENT VARIABLES:"
    echo "  GREYTHR_URL - GreyTHR system base URL (required for API integration)"
    echo "  GREYTHR_USERNAME - GreyTHR username (required for API integration)"
    echo "  GREYTHR_PASSWORD - GreyTHR password (required for API integration)"
    echo ""
    echo "NOTES:"
    echo "  This script assumes a working Python 3 environment and virtual environment"
    echo "  Make sure to source the virtual environment before running the script"
    echo "  Example: source venv/bin/activate"
    echo "  Ensure environment variables are set in .env file"
    echo "  Example: source .env"
    echo "  The script will automatically source the .env file if it exists"
    echo "  You can manually source the .env file by running: source .env"
    echo "  The script will automatically source the .env file if it exists"
}

# Main script logic
main() {
    # Check prerequisites first
    check_prerequisites
    
    case "${1:-help}" in
        "setup")
            setup_environment
            ;;
        "start")
            PRODUCTION_MODE=false
            start_app
            ;;
        "start-prod"|"production")
            PRODUCTION_MODE=true
            start_app
            ;;
        "stop")
            stop_app
            ;;
        "restart")
            PRODUCTION_MODE=false
            restart_app
            ;;
        "restart-prod"|"restart-production")
            PRODUCTION_MODE=true
            restart_app
            ;;
        "status")
            status_app
            ;;
        "logs")
            logs_app
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            echo "❌ Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
