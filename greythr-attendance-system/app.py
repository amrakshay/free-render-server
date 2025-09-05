#!/usr/bin/env python3
"""
GreyTHR Attendance System - Simple Flask Server
REST API interface for GreyTHR attendance marking
"""

import logging
import sys
import asyncio
import time
from datetime import datetime
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

async def background_attendance_worker(action, request_id):
    """Background worker to handle actual GreyTHR attendance marking (async)"""
    start_time = datetime.now()
    logger.info(f"🔄 [BG-{request_id}] Starting background {action} job at {start_time}")
    
    try:
        # Initialize GreyTHR API
        greythr_api = GreytHRAttendanceAPI()
        
        # Perform login and attendance marking (now async)
        logger.info(f"🔐 [BG-{request_id}] Starting GreyTHR login...")
        login_success = await greythr_api.login_and_get_cookies()
        
        if not login_success:
            logger.error(f"❌ [BG-{request_id}] Login failed")
            return
        
        logger.info(f"🎯 [BG-{request_id}] Login successful, marking attendance...")
        attendance_success = await greythr_api.mark_attendance(action)
        
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        
        if attendance_success:
            logger.info(f"✅ [BG-{request_id}] {action} completed successfully in {duration:.1f}s")
        else:
            logger.error(f"❌ [BG-{request_id}] {action} failed after {duration:.1f}s")
            
    except Exception as e:
        end_time = datetime.now()
        duration = (end_time - start_time).total_seconds()
        logger.error(f"❌ [BG-{request_id}] {action} exception after {duration:.1f}s: {e}")
    
    logger.info(f"🏁 [BG-{request_id}] Background job finished")

@app.route('/')
def root():
    """Root endpoint"""
    logger.info("Root endpoint accessed")
    return jsonify({
        "service": "GreyTHR Attendance System",
        "mode": "Async Background Processing",
        "endpoints": {
            "root": "/",
            "healthcheck": "/health",
            "signin": "/signin (async - returns immediately)",
            "signout": "/signout (async - returns immediately)"
        },
        "features": {
            "immediate_response": True,
            "background_processing": True,
            "estimated_completion": "2-3 minutes",
            "tracking": "Check logs for request_id progress"
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
async def signin():
    """Sign in endpoint - Async with immediate response"""
    request_id = f"signin-{int(time.time())}"
    logger.info(f"📥 [REQ-{request_id}] Signin request received")
    
    try:
        # Start background task (async)
        asyncio.create_task(background_attendance_worker("Signin", request_id))
        
        logger.info(f"🚀 [REQ-{request_id}] Background signin task started")
        
        # Return immediate success response
        return jsonify({
            "success": True,
            "message": "Signin request accepted and processing in background",
            "request_id": request_id,
            "estimated_completion": "2-3 minutes"
        })
        
    except Exception as e:
        logger.error(f"❌ [REQ-{request_id}] Failed to start background task: {e}")
        return jsonify({
            "success": False, 
            "error": f"Failed to start background task: {str(e)}",
            "request_id": request_id
        }), 500

@app.route('/signout', methods=['GET'])
async def signout():
    """Sign out endpoint - Async with immediate response"""
    request_id = f"signout-{int(time.time())}"
    logger.info(f"📥 [REQ-{request_id}] Signout request received")

    try:
        # Start background task (async)
        asyncio.create_task(background_attendance_worker("Signout", request_id))
        
        logger.info(f"🚀 [REQ-{request_id}] Background signout task started")
        
        # Return immediate success response
        return jsonify({
            "success": True,
            "message": "Signout request accepted and processing in background",
            "request_id": request_id,
            "estimated_completion": "2-3 minutes"
        })
        
    except Exception as e:
        logger.error(f"❌ [REQ-{request_id}] Failed to start background task: {e}")
        return jsonify({
            "success": False, 
            "error": f"Failed to start background task: {str(e)}",
            "request_id": request_id
        }), 500

if __name__ == '__main__':
    logger.info("🚀 Starting GreyTHR Attendance System...")
    logger.info("📍 Available at: http://0.0.0.0:5000")
    
    app.run(host='0.0.0.0', port=5000, debug=True)
