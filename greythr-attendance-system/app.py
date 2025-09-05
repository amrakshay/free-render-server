#!/usr/bin/env python3
"""
GreyTHR Attendance System - Simple Flask Server
REST API interface for GreyTHR attendance marking
"""

import logging
import sys
from flask import Flask, jsonify
from greythr_api import GreytHRAttendanceAPI

# Configure logging for the entire application
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

# Suppress Flask development server warning
logging.getLogger('werkzeug').setLevel(logging.ERROR)

# Get logger for this module
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/')
def root():
    """Root endpoint"""
    logger.info("Root endpoint accessed")
    return jsonify({
        "service": "GreyTHR Attendance System",
        "endpoints": {
            "root": "/",
            "healthcheck": "/health",
            "signin": "/signin",
            "signout": "/signout"
        }
    })

@app.route('/health')
def healthcheck():
    """Health check endpoint"""
    logger.info("Health check endpoint accessed")
    return jsonify({
        "status": "healthy"
    })

@app.route('/signin', methods=['GET'])
def signin():
    """Sign in endpoint"""
    logger.info("📥 Signin request received")

    try:
        logger.info("🔄 Calling GreyTHR mark_attendance for Signin")
        greythr_api = GreytHRAttendanceAPI()
        greythr_api.login_and_get_cookies()
        success = greythr_api.mark_attendance("Signin")
        
        if success:
            logger.info("✅ Signin successful")
            return jsonify({"success": True})
        else:
            logger.error("❌ Signin failed - GreyTHR API returned False")
            return jsonify({"success": False, "error": "Sign in failed"}), 500
    except Exception as e:
        logger.error(f"❌ Signin exception: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/signout', methods=['GET'])
def signout():
    """Sign out endpoint"""
    logger.info("📥 Signout request received")

    try:
        logger.info("🔄 Calling GreyTHR mark_attendance for Signout")
        greythr_api = GreytHRAttendanceAPI()
        greythr_api.login_and_get_cookies()
        success = greythr_api.mark_attendance("Signout")
        
        if success:
            logger.info("✅ Signout successful")
            return jsonify({"success": True})
        else:
            logger.error("❌ Signout failed - GreyTHR API returned False")
            return jsonify({"success": False, "error": "Sign out failed"}), 500
    except Exception as e:
        logger.error(f"❌ Signout exception: {e}")
        return jsonify({"success": False, "error": str(e)}), 500

if __name__ == '__main__':
    logger.info("🚀 Starting GreyTHR Attendance System...")
    logger.info("📍 Available at: http://0.0.0.0:5000")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
