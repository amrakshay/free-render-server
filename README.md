# Free Render Server: Run Always-On Apps for Free

A practical guide and ready-to-deploy Docker setup to run small, always-on servers for free on Render.com. It includes:
- nginx reverse proxy for path-based routing to multiple apps inside one container
- optional ngrok TCP tunnel to SSH into a Render free instance (which normally doesn’t allow SSH)
- a real production use case: a GreyTHR Attendance Flask microservice with Selenium login and Telegram notifications
- scripts to build, run locally, and deploy on Render
- instructions to keep the free instance alive using cron-job.org pings


## Why I built this
I always wanted a free server in the cloud that stays up 24x7 for small services. I didn’t mind low capacity—I just didn’t want to pay. While browsing, I found Render.com which offers a free web service if you provide a Docker image.

Two challenges with Render free tier:
- If there’s no traffic for ~10–15 minutes, the service sleeps.
- You can’t SSH into the instance.

How I solved it:
- Keep-alive: Use cron-job.org to send an HTTP request every 5 minutes so the service never idles.
- SSH access: Bundle ngrok into the container and expose a TCP tunnel for port 22, so I can SSH via the ngrok address.

Then I wanted multiple apps in one container with a single public URL. I added nginx to do path-based routing (e.g., /greythr → Flask app, /n8n → n8n if enabled). With that, I can run multiple lightweight services behind one Render free service.

The main app here is a GreyTHR Attendance microservice that automates daily Signin/Signout via Selenium and sends Telegram notifications. I trigger these endpoints on a schedule from cron-job.org.


## Repository layout
- `Dockerfile`: Alpine-based image with nginx, Python, optional n8n and ngrok, SSH setup
- `nginx.conf`: Path-based routing: `/greythr/` → Flask app on 5000, `/n8n/` → n8n (optional), `/health`, `/ngrok`
- `start_services.sh`: Entry script to start sshd, nginx, optional ngrok tunnel, and the GreyTHR app
- `docker-compose.yml`: Local build/run config and environment wiring
- `build_image.sh`: Helper to build the image with optional features
- `start_container.sh`: Helper to spin up the container locally with docker-compose
- `env.example`: Configuration template for build/runtime env vars
- `greythr-attendance-system/`: Flask app with `app.py` and `greythr_api.py`
- `fastapi-server/fastapi-server.sh`: Optional helper to deploy a sample FastAPI app (example pattern)


## Features
- Multiple apps via nginx path routing (single public URL)
- SSH into Render free instance via ngrok TCP tunnel
- Keep-alive using cron-job.org HTTP pings
- Real app: GreyTHR attendance automation with Telegram notifications
- Optional n8n workflow automation (disabled by default)


## Quick start (local)
Prereqs: Docker + Docker Compose

1) Copy env file and set values
```bash
cd free-render-server
cp env.example .env
# edit .env and set GREYTHR_*, TELEGRAM_* and optionally NGROK_* vars
```

2) Build image
```bash
./build_image.sh
```

3) Start container
```bash
./start_container.sh
# Health:   http://localhost/health
# GreyTHR:  http://localhost/greythr/
# n8n:      http://localhost/n8n (if enabled)
```

4) View logs
```bash
docker-compose logs -f
```

5) Stop
```bash
docker-compose down
```


## Deploying to Render for free
Render service type: Web Service (Docker)

- Create a new Web Service on Render and point it to published docker image.
- Add environment variables from your `.env` to Render’s dashboard.
- Optional: Set `NGROK_ENABLED=true` and provide `NGROK_AUTHTOKEN` to enable SSH tunnel.

Keep-alive to prevent sleeping:
- Go to `https://cron-job.org` and create a job that hits your Render URL every 5 minutes.
- Example URL: `https://your-service.onrender.com/health`


## SSH access via ngrok (optional)
Render’s free tier does not allow direct SSH. This image can open an ngrok TCP tunnel to port 22.

Enable it:
- Build with `INSTALL_NGROK=true` (default in `build_image.sh`).
- Set at runtime: `NGROK_ENABLED=true` and optionally `NGROK_AUTHTOKEN` for persistent tunnels.

Find the tunnel URL in server logs:
- It looks like: `tcp://x.tcp.ngrok.io:NNNNN`

SSH command:
```bash
ssh root@x.tcp.ngrok.io -p NNNNN
```
Security tip: Change the root password or disable password auth in the Dockerfile for production. Prefer keys.


## Multi-app routing with nginx
- Add more apps inside the container and bind them to different internal ports.
- Update `nginx.conf` with additional `location /myapp/ { proxy_pass http://127.0.0.1:PORT; }` blocks.
- Rebuild and redeploy. All apps share the same Render URL, routed by path.


## GreyTHR Attendance microservice
A Flask server that exposes async endpoints to mark attendance in GreyTHR using Selenium. It sends Telegram updates for success/failure.

Endpoints (proxied by nginx):
- `GET /greythr/` – info
- `GET /greythr/health` – health check
- `GET /greythr/signin` – triggers background Signin
- `GET /greythr/signout` – triggers background Signout

Schedule with cron-job.org:
- Create two cron jobs to call `/greythr/signin` and `/greythr/signout` at your desired times.

Required environment variables
- GREYTHR_ENABLED=true
- GREYTHR_URL=Your GreyTHR login URL (e.g., `https://company.greythr.com`)
- GREYTHR_USERNAME=Your username
- GREYTHR_PASSWORD=Base64 encoded password (see below)
- TELEGRAM_BOT_TOKEN=Telegram bot token
- TELEGRAM_CHAT_ID=Your chat ID

Encoding the password
```bash
echo -n "your_password" | base64
# copy the output into GREYTHR_PASSWORD
```

Notes
- `greythr_api.py` launches headless Chromium inside the container and transfers cookies from Selenium into the `requests` session before calling GreyTHR’s API.
- The container installs `chromium` and `chromium-chromedriver` to support this.
- Timeouts are tuned for cloud environments.


## Optional: n8n workflow automation
You can bundle n8n and expose it at `/n8n/`.

- Build with `INSTALL_N8N=true` (large image).
- Run with `N8N_ENABLED=true`.


## Environment variables
Build-time (influences image size/capabilities):
- INSTALL_N8N=false|true
- INSTALL_NGROK=true|false

Runtime:
- N8N_ENABLED=false|true
- NGROK_ENABLED=false|true
- NGROK_AUTHTOKEN=...
- GREYTHR_ENABLED=true|false
- GREYTHR_URL=...
- GREYTHR_USERNAME=...
- GREYTHR_PASSWORD=... (base64)
- TELEGRAM_BOT_TOKEN=...
- TELEGRAM_CHAT_ID=...

See `env.example` for documentation and examples.


## Security considerations
- Treat your `.env` as secrets—do not commit it. Configure secrets in Render’s dashboard.
- The GreyTHR password must be provided as base64 in env; it is decoded only in-memory.


## Scripts
- `./build_image.sh` – builds with your chosen options
- `./start_container.sh` – runs with docker-compose and prints helpful URLs
- `docker-compose.yml` – defines the service and env mapping


## Keep-alive setup summary
- Create a cron job at cron-job.org to ping `/health` every 5 minutes.
- This prevents Render from idling the free service.


## My story, distilled
- Wanted a free, always-on cloud server
- Found Render free Docker service but it sleeps and lacks SSH
- Solved sleep with cron-job.org pings; solved SSH with ngrok TCP tunnel
- Added nginx to route multiple apps via one public URL
- Built a real use case: automated GreyTHR attendance with Telegram notifications
- Everything runs reliably for free, with minimal resources