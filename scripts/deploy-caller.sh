#!/bin/bash
set -x  # Enable debug logging to cloud-init-output.log
set -e

# Ensure environment is set for non-interactive root shell
export HOME=/root
export USER=root
export DEBIAN_FRONTEND=noninteractive

# Startup script for the caller / gateway VM
INFERENCE_IP="${inference_ip}"
if [ -z "$INFERENCE_IP" ]; then
  echo "FATAL: inference_ip not set" >&2
  exit 1
fi

echo "[+] starting caller/gateway setup..."

# 0. Add Swap (Crucial for t3.micro/1GB RAM)
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 1. Register services IMMEDIATELY
cat > /etc/systemd/system/iii-engine.service << EOF
[Unit]
Description=iii Engine (RPC Hub)
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/devops-assignment
Environment="III_ENGINE_HOST=0.0.0.0"
ExecStart=/usr/local/bin/iii engine start --config config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/caller-worker.service << 'EOF'
[Unit]
Description=Caller Worker (TypeScript) — HTTP Gateway
After=iii-engine.service
Requires=iii-engine.service

[Service]
Type=simple
WorkingDirectory=/opt/devops-assignment/workers/call-worker
Environment="III_URL=ws://localhost:49134"
ExecStart=/usr/local/bin/bun run index.ts
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
# 2. Install Basics
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y git curl unzip nodejs libcap-ng0 jq

# 3. Install Bun
curl -fsSL https://bun.sh/install | bash
cp /root/.bun/bin/bun /usr/local/bin/bun
chmod +x /usr/local/bin/bun

# 4. Install the iii engine
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh || true

# Force the binary to /usr/local/bin if it went elsewhere
III_PATH=$(which iii || echo "/usr/bin/iii")
if [ -f "$III_PATH" ]; then
  cp "$III_PATH" /usr/local/bin/iii
fi

# As a fallback, download it directly if the installer failed
if [ ! -f /usr/local/bin/iii ]; then
  curl -Lo /usr/local/bin/iii https://github.com/Alchemyst-ai/hiring/releases/download/v0.11.0/iii-linux-amd64
fi

chmod +x /usr/local/bin/iii
ls -l /usr/local/bin/iii


# 5. Clone and Setup
cd /opt
git clone ${repo_url} devops-assignment || (cd devops-assignment && git pull)
mkdir -p /opt/devops-assignment/data

# 6. Install Deps
cd /opt/devops-assignment/workers/call-worker
/usr/local/bin/bun install

# 7. Start services
systemctl enable iii-engine
systemctl start iii-engine
systemctl enable caller-worker
systemctl start caller-worker

echo "[+] caller/gateway setup done"
