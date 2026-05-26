#!/bin/bash
set -x
set -e

# Ensure environment is set for non-interactive root shell
export HOME=/root
export USER=root
export DEBIAN_FRONTEND=noninteractive

# Startup script for the inference VM
CALLER_IP="${caller_ip}"
if [ -z "$CALLER_IP" ]; then
  echo "FATAL: caller_ip not set" >&2
  exit 1
fi

echo "[+] starting inference worker setup..."

# 0. Add Swap (Crucial for t3.micro/1GB RAM)
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# 1. Register service IMMEDIATELY
cat > /etc/systemd/system/inference-worker.service << EOF
[Unit]
Description=Inference Worker (Python)
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/devops-assignment/workers/inference-worker
Environment="III_URL=ws://$CALLER_IP:49134"
Environment="PATH=/root/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/root/.local/bin/uv run main.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

# 2. Install Basics
apt-get update -y
apt-get install -y git curl python3-pip

# 3. Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="/root/.local/bin:$PATH"

# 4. Clone and Setup
cd /opt
git clone ${repo_url} devops-assignment || (cd devops-assignment && git pull)
cd devops-assignment/workers/inference-worker

# 5. Install python 3.14 and dependencies
/root/.local/bin/uv python install 3.14
/root/.local/bin/uv sync

# 6. Start service
systemctl enable inference-worker
systemctl start inference-worker

echo "[+] inference worker setup done"
