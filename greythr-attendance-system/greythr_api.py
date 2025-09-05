
import time
import requests
import json
import os
import logging
import base64
import tempfile
import uuid
import shutil

# Selenium imports
try:
    from selenium import webdriver
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.keys import Keys
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC
    from selenium.webdriver.chrome.options import Options
    from selenium.webdriver.chrome.service import Service
    SELENIUM_AVAILABLE = True
except ImportError:
    SELENIUM_AVAILABLE = False

# Get logger for this module - will inherit from root logger configuration
logger = logging.getLogger('greythr_api')


class GreytHRAttendanceAPI:
    def __init__(self):
        logger.info("🔧 Initializing GreyTHR API...")
        
        # Get configuration from environment variables
        self.base_url = os.getenv('GREYTHR_URL')
        if not self.base_url:
            logger.error("❌ GREYTHR_URL environment variable not set")
            raise ValueError("GREYTHR_URL environment variable is required")
            
        if not self.base_url.endswith('/'):
            self.base_url += '/'

        self.greythr_username = os.getenv('GREYTHR_USERNAME')
        if not self.greythr_username:
            logger.error("❌ GREYTHR_USERNAME environment variable not set")
            raise ValueError("GREYTHR_USERNAME environment variable is required")

        # Get base64 encoded password and decode it
        greythr_password_b64 = os.getenv('GREYTHR_PASSWORD')
        if not greythr_password_b64:
            logger.error("❌ GREYTHR_PASSWORD environment variable not set")
            raise ValueError("GREYTHR_PASSWORD environment variable is required")
        
        try:
            # Decode base64 encoded password
            self.greythr_password = base64.b64decode(greythr_password_b64).decode('utf-8')
            logger.info("🔐 Password decoded from base64 successfully")
        except Exception as e:
            logger.error(f"❌ Failed to decode base64 password: {e}")
            raise ValueError("GREYTHR_PASSWORD must be a valid base64 encoded string")
        
        self.api_base = f"{self.base_url.rstrip('/')}/v3/api"
        self.attendance_api = f"{self.api_base}/attendance/mark-attendance"
        
        logger.info(f"🌐 Base URL: {self.base_url}")
        logger.info(f"🔗 Attendance API: {self.attendance_api}")
        
        # Initialize requests session
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache'
        })
        
        logger.info("✅ GreyTHR API initialized successfully")

    def login_and_get_cookies(self):
        """
        Login using Selenium and extract cookies for API calls
        """
        if not SELENIUM_AVAILABLE:
            logger.error("❌ Selenium not available for login")
            return False

        logger.info("🚀 Starting Login Process...")
        logger.info("🚀 Starting browser-based login process...")
        
        # Setup Chromium options for cloud deployment (Render.com compatible)
        chrome_options = Options()
        chrome_options.add_argument("--headless")  # Run in background
        chrome_options.add_argument("--no-sandbox")  # Required for container
        chrome_options.add_argument("--disable-dev-shm-usage")  # Required for container
        chrome_options.add_argument("--disable-gpu")  # Disable GPU in headless mode
        chrome_options.add_argument("--disable-web-security")  # Disable web security
        chrome_options.add_argument("--disable-features=VizDisplayCompositor")  # Stability
        
        # Fix for "DevToolsActivePort file doesn't exist" error in cloud environments
        chrome_options.add_argument("--remote-debugging-port=0")  # Disable remote debugging
        chrome_options.add_argument("--disable-dev-tools")  # Disable DevTools completely
        chrome_options.add_argument("--disable-extensions-http-throttling")
        chrome_options.add_argument("--disable-logging")  # Disable logging
        chrome_options.add_argument("--disable-default-apps")
        chrome_options.add_argument("--disable-component-extensions-with-background-pages")
        
        # Create unique user data directory for this session to avoid conflicts
        session_id = str(uuid.uuid4())[:8]  # Short unique ID
        user_data_dir = f"/tmp/chromium-{session_id}"
        cache_dir = f"/tmp/chromium-cache-{session_id}"
        
        chrome_options.add_argument(f"--user-data-dir={user_data_dir}")
        chrome_options.add_argument(f"--data-path={user_data_dir}/data")
        chrome_options.add_argument("--homedir=/tmp")
        chrome_options.add_argument(f"--disk-cache-dir={cache_dir}")
        
        # Additional cloud platform optimizations (enabled for better cloud performance)
        # chrome_options.add_argument("--disable-extensions")  # Disable extensions
        # chrome_options.add_argument("--disable-plugins")  # Disable plugins
        # chrome_options.add_argument("--disable-images")  # Disable image loading for speed
        # chrome_options.add_argument("--no-zygote")  # Disable zygote process
        # chrome_options.add_argument("--disable-background-timer-throttling")
        # chrome_options.add_argument("--disable-backgrounding-occluded-windows")
        # chrome_options.add_argument("--disable-renderer-backgrounding")
        # chrome_options.add_argument("--disable-background-networking")
        # chrome_options.add_argument("--disable-ipc-flooding-protection")
        # chrome_options.add_argument("--memory-pressure-off")  # Disable memory pressure
        # chrome_options.add_argument("--max_old_space_size=4096")  # Increase memory limit
        
        # Resource optimization for cloud environments
        chrome_options.add_argument("--aggressive-cache-discard")
        chrome_options.add_argument("--no-first-run")  # Skip first run setup
        
        # Anti-detection (keep some for compatibility)
        chrome_options.add_argument("--disable-blink-features=AutomationControlled")
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option('useAutomationExtension', False)
        chrome_options.add_argument("--window-size=1920,1080")
        
        # Use system Chromium binary (Alpine Linux)
        chrome_options.binary_location = "/usr/bin/chromium-browser"
        
        # Create unique temporary directories for this session
        temp_dirs = [user_data_dir, f"{user_data_dir}/data", cache_dir]
        for temp_dir in temp_dirs:
            os.makedirs(temp_dir, exist_ok=True)
        
        logger.info(f"🗂️  Created unique session directories: {session_id}")
        
        driver = None
        try:
            # Initialize WebDriver with system ChromeDriver
            logger.info("🔧 Setting up Chromium browser...")
            service = Service("/usr/bin/chromedriver")  # Use system chromedriver
            driver = webdriver.Chrome(service=service, options=chrome_options)
            
            # Extended timeouts for cloud environments (Render.com)
            driver.set_page_load_timeout(90)  # Increased from 30s to 90s
            driver.implicitly_wait(20)  # Wait up to 20s for elements
            
            # Login process
            logger.info(f"🔐 Logging in to: {self.base_url}")
            driver.get(self.base_url)
            time.sleep(10)  # Extended wait for cloud environments (was 5s)
            
            # Find and fill login fields
            logger.info("🔍 Finding login fields...")
            
            # Find username field
            username_selectors = [
                "input[name*='user']",
                "input[name*='email']", 
                "input[type='email']",
                "input[type='text']:first-of-type"
            ]
            
            username_field = None
            for selector in username_selectors:
                try:
                    username_field = WebDriverWait(driver, 30).until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, selector))
                    )
                    logger.info("✅ Username field found")
                    break
                except:
                    continue
            
            if not username_field:
                logger.error("❌ Could not find username field")
                return False
            
            # Find password field
            try:
                password_field = driver.find_element(By.CSS_SELECTOR, "input[type='password']")
                logger.info("✅ Password field found")
            except:
                logger.error("❌ Could not find password field")
                return False
            
            # Fill credentials
            logger.info("📝 Entering credentials...")
            username_field.clear()
            username_field.send_keys(self.greythr_username)
            password_field.clear()
            password_field.send_keys(self.greythr_password)
            
            # Submit login
            try:
                submit_button = driver.find_element(By.CSS_SELECTOR, "button[type='submit']")
                submit_button.click()
            except:
                password_field.send_keys(Keys.RETURN)
            
            logger.info("🔘 Login submitted, waiting...")
            time.sleep(5)
            
            # Check if login successful
            if "dashboard" in driver.current_url.lower() or "home" in driver.current_url.lower():
                logger.info("✅ Login successful!")
                logger.info(f"✅ Login successful - redirected to {driver.current_url}")
            else:
                logger.warning(f"⚠️ Redirected to: {driver.current_url}")
                logger.warning(f"⚠️ Unexpected redirect to: {driver.current_url}")
            
            # Extract cookies
            logger.info("🍪 Extracting cookies...")
            logger.info("🍪 Extracting cookies for API authentication...")
            selenium_cookies = driver.get_cookies()
            
            # Transfer cookies to requests session
            for cookie in selenium_cookies:
                self.session.cookies.set(
                    cookie['name'], 
                    cookie['value'],
                    domain=cookie.get('domain'),
                    path=cookie.get('path', '/'),
                    secure=cookie.get('secure', False)
                )
            
            logger.info(f"✅ Transferred {len(selenium_cookies)} cookies to session")
            logger.info(f"✅ Transferred {len(selenium_cookies)} cookies to requests session")
            
            # Log important cookies for debugging
            important_cookies = ['access_token', 'PLAY_SESSION']
            for cookie_name in important_cookies:
                cookie_value = self.session.cookies.get(cookie_name)
                if cookie_value:
                    logger.info(f"🔑 {cookie_name}: {cookie_value[:20]}...")
                    logger.debug(f"🔑 Found {cookie_name}: {cookie_value[:20]}...")
                else:
                    logger.warning(f"⚠️ {cookie_name}: Not found")
                    logger.warning(f"⚠️ {cookie_name}: Not found")
            
            return True
            
        except Exception as e:
            logger.error(f"❌ Login error: {e}", exc_info=True)
            return False
            
        finally:
            if driver:
                logger.debug("🛑 Closing browser driver")
                driver.quit()
            
            # Clean up temporary directories
            cleanup_dirs = [user_data_dir, cache_dir]
            for cleanup_dir in cleanup_dirs:
                try:
                    if os.path.exists(cleanup_dir):
                        shutil.rmtree(cleanup_dir)
                        logger.debug(f"🗑️  Cleaned up: {cleanup_dir}")
                except Exception as cleanup_error:
                    logger.warning(f"⚠️  Failed to cleanup {cleanup_dir}: {cleanup_error}")

    def mark_attendance(self, action="Signin"):
        """
        Mark attendance using the API endpoint
        action can be "Signin" or "Signout"
        """
        logger.info(f"🎯 MARKING ATTENDANCE: {action.upper()}")
        logger.info(f"🎯 Starting attendance API call: {action.upper()}")
        
        # Prepare API request
        url = f"{self.attendance_api}?action={action}"
        
        # Empty JSON payload as shown in your curl
        payload = {}
        
        logger.info(f"📤 API Request: POST {url}")
        logger.debug(f"📤 Request payload: {json.dumps(payload)}")
        
        try:
            # Make the API request with extended timeout for cloud environments
            response = self.session.post(
                url,
                json=payload,
                timeout=90  # Increased from 30s to 90s for cloud deployment
            )
            
            logger.info(f"📥 API Response: Status {response.status_code}")
            logger.debug(f"📥 Response headers: {dict(response.headers)}")
            
            # Try to parse response as JSON
            try:
                response_data = response.json()
                logger.debug(f"📥 JSON Response: {json.dumps(response_data, indent=2)}")
            except:
                logger.debug(f"📥 Text Response: {response.text}")
            
            if response.status_code == 200:
                logger.info(f"✅ {action} SUCCESSFUL!")
                return True
            else:
                logger.error(f"❌ {action} FAILED! Status: {response.status_code}")
                return False
                
        except Exception as e:
            logger.error(f"❌ API request error: {e}", exc_info=True)
            return False