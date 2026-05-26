#!/bin/bash
set -e

# Startup script for the inference VM
# Runs after VM boots, sets up the Python inference worker

CALLER_IP="${caller_ip}"
if [ -z "$CALLER_IP" ]; then
  echo "FATAL: caller_ip not set" >&2
  exit 1
fi

echo "[+] starting inference worker setup..."
echo "[+] caller (hub) is at $CALLER_IP"

# Basics
apt-get update -y && apt-get install -y git curl python3-pip

# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="/root/.local/bin:$PATH"

# Clone the repo
cd /opt
git clone ${repo_url} devops-assignment || true
cd devops-assignment/workers/inference-worker

# Install python 3.14 and dependencies
uv python install 3.14
uv sync

# systemd unit for the inference worker
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
systemctl enable inference-worker
systemctl start inference-worker

echo "[+] inference worker setup done"
