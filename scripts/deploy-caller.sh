
#!/bin/bash
set -e

# Startup script for the caller / gateway VM
# Runs after VM boots, sets up the TS caller worker + exposes it via HTTP

INFERENCE_IP="${inference_ip}"
if [ -z "$INFERENCE_IP" ]; then
  echo "FATAL: inference_ip not set" >&2
  exit 1
fi

echo "[+] starting caller/gateway setup..."
echo "[+] inference worker is at $INFERENCE_IP"

# Basics
apt-get update -y && apt-get install -y git curl unzip

# Install node (still needed for some things potentially, but we'll use bun)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install Bun
curl -fsSL https://bun.sh/install | bash
# Copy to a place where systemd can always find it
cp /root/.bun/bin/bun /usr/local/bin/bun
chmod +x /usr/local/bin/bun

# Install the iii engine (hub)
curl -Lo /usr/local/bin/iii https://github.com/Alchemyst-ai/hiring/releases/download/v0.11.0/iii-linux-amd64
chmod +x /usr/local/bin/iii

# Clone the repo
cd /opt
git clone ${repo_url} devops-assignment || true
cd devops-assignment
mkdir -p data
cd workers/call-worker

# Install deps
/usr/local/bin/bun install

# systemd unit for the iii engine (hub)
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

# systemd unit for the caller 
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

# RELOAD AND START
systemctl daemon-reload
systemctl enable iii-engine
systemctl start iii-engine
systemctl enable caller-worker
systemctl start caller-worker

echo "[+] caller/gateway setup done"
echo "[+] gateway should be listening on port 8000"
