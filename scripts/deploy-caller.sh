#!/bin/bash
set -e

# Startup script for the caller / gateway VM
INFERENCE_IP="${inference_ip}"
if [ -z "$INFERENCE_IP" ]; then
  echo "FATAL: inference_ip not set" >&2
  exit 1
fi

echo "[+] starting caller/gateway setup..."

# 1. Register services IMMEDIATELY so they are visible even while installing
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
apt-get install -y git curl unzip nodejs

# 3. Install Bun
curl -fsSL https://bun.sh/install | bash
cp /root/.bun/bin/bun /usr/local/bin/bun
chmod +x /usr/local/bin/bun

# 4. Install the iii engine binary
curl -Lo /usr/local/bin/iii https://github.com/Alchemyst-ai/hiring/releases/download/v0.11.0/iii-linux-amd64
chmod +x /usr/local/bin/iii

# 5. Clone and Setup
cd /opt
git clone ${repo_url} devops-assignment || (cd devops-assignment && git pull)
mkdir -p /opt/devops-assignment/data

# 6. Install Deps (This part is slow)
cd /opt/devops-assignment/workers/call-worker
/usr/local/bin/bun install

# 7. Start services
systemctl enable iii-engine
systemctl start iii-engine
systemctl enable caller-worker
systemctl start caller-worker

echo "[+] caller/gateway setup done"
