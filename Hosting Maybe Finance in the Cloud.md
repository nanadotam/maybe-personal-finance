  Hosting Maybe Finance in the Cloud -- Complete Walkthrough

  What You're Working With

  Maybe is a Ruby on Rails app containerized with Docker. It runs 4 services:

- web -- the Rails app (port 3000)
- worker -- Sidekiq background job processor
- db -- PostgreSQL 16
- redis -- Redis for Sidekiq/caching

  Good news: Maybe already has PWA support built in. It ships with a manifest.json
  (app/views/pwa/manifest.json.erb) and a service worker scaffold
  (app/views/pwa/service-worker.js). Once it's live on HTTPS, you can "Add to Home
  Screen" on your phone and it'll behave like a native app.

---

  Free/Low-Cost Hosting Options (Ranked)

  Option 1: Oracle Cloud Always Free (Best Free Option)

  Cost: $0 forever -- Oracle's "Always Free" tier never expires.

  What you get:

- ARM instance: Up to 4 OCPUs + 24 GB RAM (VM.Standard.A1.Flex) -- more than enough
- 47 GB boot volume storage
- 10 TB/month outbound data

  This is the most generous free tier available. You can run Maybe's entire Docker
  Compose stack on a single ARM VM with plenty of headroom.

  Walkthrough:

# 1. Sign up at https://www.oracle.com/cloud/free/

# Create an Always Free ARM instance (VM.Standard.A1.Flex)

# Choose Ubuntu 22.04+ as the OS

# Allocate at least 2 OCPUs + 6 GB RAM (free allows up to 4/24)

# 2. SSH into your instance

  ssh -i your-key.pem ubuntu@`<your-instance-ip>`

# 3. Install Docker

  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o
  /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg]
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo
  "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >
  /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# 4. Add your user to docker group

  sudo usermod -aG docker $USER
  newgrp docker

# 5. Create the app directory

  mkdir -p ~/maybe && cd ~/maybe

# 6. Download the compose file

  curl -o compose.yml
  https://raw.githubusercontent.com/maybe-finance/maybe/main/compose.example.yml

# 7. Create your .env file

  cat > .env << 'EOF'
  SECRET_KEY_BASE=$(openssl rand -hex 64)
  POSTGRES_PASSWORD=$(openssl rand -hex 32)
  EOF

# Actually generate the values:

  echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > .env
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 32)" >> .env

# 8. Start the app

  docker compose up -d

# 9. Verify it's running

  docker compose ls

  Opening the firewall (Oracle Cloud specific):

# On the VM itself, open port 3000

  sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
  sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
  sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT
  sudo netfilter-persistent save

# ALSO go to Oracle Cloud Console:

# Networking > Virtual Cloud Networks > your VCN > Security Lists

# Add ingress rules for ports 80, 443 (and 3000 temporarily)

  Adding HTTPS with Caddy (required for PWA):

# Add a Caddy reverse proxy to your compose.yml or run standalone:

  sudo apt install -y caddy

# Create Caddyfile

  sudo tee /etc/caddy/Caddyfile << 'EOF'
  your-domain.com {
      reverse_proxy localhost:3000
  }
  EOF

  sudo systemctl restart caddy

  Caddy automatically provisions and renews Let's Encrypt SSL certs. You need a domain
  pointed at your Oracle instance IP.

---

  Option 2: Coolify on a Cheap VPS (Easiest Management)

  Coolify is a free, open-source, self-hosted PaaS -- think Heroku but you own it. It
  gives you a web UI to deploy Docker Compose apps with automatic SSL, backups, and
  git-based deploys.

  Cost: $0 for Coolify itself + cost of VPS

- Hetzner: ~$4/month (CX22, 2 vCPU, 4 GB RAM)
- Contabo: ~$5/month
- Or install Coolify on your free Oracle Cloud instance

  Setup:

# 1. Get a VPS (or use your Oracle free instance)

# 2. SSH in and install Coolify with one command:

  curl -fsSL https://cdn.coollabs.io/coolify/install.sh | bash

# 3. Access Coolify at http://`<your-ip>`:8000

# 4. In the Coolify dashboard:

# - Add your server

# - Create new project > Docker Compose

# - Paste the compose.example.yml contents

# - Set environment variables (SECRET_KEY_BASE, POSTGRES_PASSWORD)

# - Add your custom domain

* [ ] - Deploy!

# Coolify handles SSL automatically via Let's Encrypt

---

  Option 3: Fly.io (Generous Free Tier)

  Fly.io gives you 3 shared VMs (256 MB each) and 3 GB persistent storage free.

  This is tight for Maybe (needs Postgres + Redis + Rails + Sidekiq), but workable if
  you use Fly's managed Postgres and configure small machines.

---

  Option 4: Railway (Simplest Deploy, Limited Free)

  Railway gives you $5/month free credit. May not last the full month depending on
  usage but is the easiest to set up -- just connect your GitHub repo.

---

  Getting a Free Domain

- Freenom alternatives (freenom shut down): Use DuckDNS for free dynamic DNS
  subdomains
- Cloudflare Tunnel: Free, no need for a domain -- exposes your local/cloud app
  securely via a cloudflared tunnel with HTTPS

# Cloudflare Tunnel approach (works great with Oracle Cloud):

# 1. Sign up at https://dash.cloudflare.com

# 2. Go to Zero Trust > Access > Tunnels > Create

# 3. Install cloudflared on your server:

  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo gpg --dearmor -o
  /usr/share/keyrings/cloudflare.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloudflare.gpg]
  https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" | sudo tee
  /etc/apt/sources.list.d/cloudflare.list
  sudo apt update && sudo apt install cloudflared

# 4. Login and create tunnel

  cloudflared tunnel login
  cloudflared tunnel create maybe
  cloudflared tunnel route dns maybe maybe.yourdomain.com

# 5. Run the tunnel

  cloudflared tunnel --url http://localhost:3000 run maybe

---

  Setting Up PWA (Access from Your Phone)

  Maybe already has PWA support built in. The manifest is at
  app/views/pwa/manifest.json.erb and is configured with:

- "display": "standalone" -- runs like a native app (no browser chrome)
- "display_override": ["fullscreen", "minimal-ui"] -- fallback options
- App icon at /logo-pwa.png

  Requirements for PWA to work:

1. Your app MUST be served over HTTPS (Caddy or Cloudflare Tunnel handles this)
2. The service worker must be registered (Rails 8 does this automatically)

  Installing on your phone:

- iPhone (Safari): Navigate to your Maybe URL > tap the Share button > "Add to Home
  Screen"
- Android (Chrome): Navigate to your Maybe URL > tap the three dots menu > "Add to
  Home Screen" or "Install App"

  It will appear as a standalone app with the Maybe icon.

---

  My Recommended Stack (100% Free)

  ┌─────────────────┬───────────────────────────────────────────────────────┬──────┐
  │    Component    │                       Solution                        │ Cost │
  ├─────────────────┼───────────────────────────────────────────────────────┼──────┤
  │ Server          │ Oracle Cloud Always Free (ARM, 4 OCPU/24 GB)          │ $0   │
  ├─────────────────┼───────────────────────────────────────────────────────┼──────┤
  │ SSL/Domain      │ Cloudflare Tunnel (free tier) or DuckDNS + Caddy      │ $0   │
  ├─────────────────┼───────────────────────────────────────────────────────┼──────┤
  │ Docker          │ Coolify (self-hosted on same server) or plain Docker  │ $0   │
  │ Management      │ Compose                                               │      │
  ├─────────────────┼───────────────────────────────────────────────────────┼──────┤
  │ PWA             │ Already built into Maybe                              │ $0   │
  ├─────────────────┼───────────────────────────────────────────────────────┼──────┤
  │ Backups         │ Cron job + pg_dump to Oracle Object Storage (10 GB    │ $0   │
  │                 │ free)                                                 │      │
  └─────────────────┴───────────────────────────────────────────────────────┴──────┘

  Total: $0/month

---

  Quick Start Summary (Oracle Cloud + Cloudflare)

# After setting up Oracle Cloud VM and SSH'ing in:

# 1. Install Docker

  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER && newgrp docker

# 2. Set up Maybe

  mkdir ~/maybe && cd ~/maybe
  curl -o compose.yml
  https://raw.githubusercontent.com/maybe-finance/maybe/main/compose.example.yml
  echo "SECRET_KEY_BASE=$(openssl rand -hex 64)" > .env
  echo "POSTGRES_PASSWORD=$(openssl rand -hex 32)" >> .env
  docker compose up -d

# 3. Set up Cloudflare Tunnel for HTTPS

# (follow Cloudflare Tunnel steps above)

# 4. Access from phone

# Visit https://maybe.yourdomain.com

# Add to Home Screen -- done, you have a PWA!

# 5. Create your account

# First visit: click "Create your account", set email + password

# That's your login for all devices

---

  Updating the App

  cd ~/maybe
  docker compose pull
  docker compose build
  docker compose up --no-deps -d web worker

---

  Sources:

- Maybe Self-Hosting Docker Guide
- Oracle Cloud Free Tier
- How to Set Up Docker on Oracle Cloud Free Tier
- Coolify -- Open-Source Self-Hosted PaaS
- 5 Cheap Ways to Deploy Docker Containers (2025)
- Rails 8 PWA Support
- Self-Host Maybe Finance on AWS
- Free Docker Hosting Providers 2026
- Coolify vs Dokploy Comparison 2026

✻ Brewed for 2m 23s

───────────────────────────────────────────────────────────────────────────────────────
❯ set up the Oracle Cloud instance with Coolify
───────────────────────────────────────────────────────────────────────────────────────
  ⏵⏵ accept edits on (shift+tab to cycle)
