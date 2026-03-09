#!/bin/bash
set -e

echo "========================================="
echo "Nana's Cloud — GCP VM Setup Script"
echo "========================================="

# Step 1: Add swap (1GB RAM is tight for Docker)
echo "[1/7] Adding 2GB swap space..."
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  echo "Swap added."
else
  echo "Swap already exists, skipping."
fi

# Step 2: Install Docker
echo "[2/7] Installing Docker..."
if ! command -v docker &> /dev/null; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker $USER
  echo "Docker installed. You may need to log out and back in for group changes."
else
  echo "Docker already installed, skipping."
fi

# Step 3: Create app directory
echo "[3/7] Creating app directory..."
mkdir -p ~/maybe-personal-finance
cd ~/maybe-personal-finance

# Step 4: Generate secrets
echo "[4/7] Generating secrets..."
SECRET_KEY=$(openssl rand -hex 64)
DB_PASSWORD=$(openssl rand -hex 16)

echo "Generated SECRET_KEY_BASE and DB password."

# Step 5: Create .env file
echo "[5/7] Creating .env file..."
if [ ! -f .env ]; then
cat > .env << ENVEOF
# Nana's Cloud — Production Environment
SECRET_KEY_BASE=${SECRET_KEY}
POSTGRES_USER=maybe_user
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=maybe_production

# Groq AI (primary LLM provider)
GROQ_API_KEY=REPLACE_WITH_YOUR_GROQ_API_KEY

# Market Data API Keys
EXCHANGERATE_API_KEY=REPLACE_OR_SET_IN_APP
FMP_API_KEY=REPLACE_OR_SET_IN_APP
ENVEOF
  echo ".env created."
else
  echo ".env already exists, skipping."
fi

# Step 6: Create dashboard directory and files
echo "[6/7] Creating dashboard..."
mkdir -p dashboard

cat > dashboard/nginx.conf << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    # Dashboard (landing page)
    location = / {
        root /usr/share/nginx/html;
        index index.html;
    }

    # Static assets for dashboard
    location /dashboard/ {
        root /usr/share/nginx/html;
        try_files $uri $uri/ =404;
    }

    # Proxy everything under /maybe/ to the Rails app
    location /maybe/ {
        proxy_pass http://web:3000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect / /maybe/;

        # WebSocket support (for Turbo/ActionCable)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 90s;
        proxy_buffering off;
    }
}
NGINXEOF

# Note: index.html should be copied from the repo's deploy/dashboard/index.html
# or created separately. The compose.yml mounts ./dashboard/index.html

echo "Dashboard config created."

# Step 7: Create compose.yml
echo "[7/7] Creating compose.yml..."
cat > compose.yml << 'COMPOSEEOF'
x-db-env: &db_env
  POSTGRES_USER: ${POSTGRES_USER:-maybe_user}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-maybe_password}
  POSTGRES_DB: ${POSTGRES_DB:-maybe_production}

x-rails-env: &rails_env
  <<: *db_env
  SECRET_KEY_BASE: ${SECRET_KEY_BASE}
  SELF_HOSTED: "true"
  RAILS_FORCE_SSL: "false"
  RAILS_ASSUME_SSL: "false"
  DB_HOST: db
  DB_PORT: 5432
  REDIS_URL: redis://redis:6379/1
  GROQ_API_KEY: ${GROQ_API_KEY}
  OPENAI_ACCESS_TOKEN: ${OPENAI_ACCESS_TOKEN:-unused}
  EXCHANGERATE_API_KEY: ${EXCHANGERATE_API_KEY}
  FMP_API_KEY: ${FMP_API_KEY}

services:
  dashboard:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./dashboard/index.html:/usr/share/nginx/html/index.html:ro
      - ./dashboard/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
    depends_on:
      web:
        condition: service_started
    networks:
      - maybe_net
    deploy:
      resources:
        limits:
          memory: 32M

  web:
    image: maybe-personal:latest
    volumes:
      - app-storage:/rails/storage
    expose:
      - "3000"
    restart: unless-stopped
    environment:
      <<: *rails_env
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - maybe_net
    deploy:
      resources:
        limits:
          memory: 512M

  worker:
    image: maybe-personal:latest
    command: bundle exec sidekiq
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      <<: *rails_env
    networks:
      - maybe_net
    deploy:
      resources:
        limits:
          memory: 256M

  db:
    image: postgres:16
    restart: unless-stopped
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      <<: *db_env
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks:
      - maybe_net
    deploy:
      resources:
        limits:
          memory: 256M

  redis:
    image: redis:latest
    restart: unless-stopped
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - maybe_net
    deploy:
      resources:
        limits:
          memory: 64M

volumes:
  app-storage:
  postgres-data:
  redis-data:

networks:
  maybe_net:
    driver: bridge
COMPOSEEOF

echo ""
echo "========================================="
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Log out and back in (for docker group)"
echo "  2. cd ~/maybe-personal-finance"
echo "  3. nano .env  — set your GROQ_API_KEY and market data keys"
echo "  4. Copy dashboard/index.html from the repo"
echo "  5. Build or pull the maybe-personal image"
echo "  6. docker compose up -d"
echo "  7. Visit http://35.227.53.189  (dashboard)"
echo "  8. Visit http://35.227.53.189/maybe/  (Maybe app)"
echo "========================================="
