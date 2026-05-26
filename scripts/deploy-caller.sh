#!/bin/bash
set -x
set -e

export HOME=/root
export USER=root
export DEBIAN_FRONTEND=noninteractive

echo "[+] starting caller/gateway setup..."

# 0. Add Swap
if [ ! -f /swapfile ]; then
  fallocate -l 1G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
fi

# 1. Register services
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
apt-get update -y
apt-get install -y git curl unzip nodejs libcap-ng0 jq

# 3. Install Bun
curl -fsSL https://bun.sh/install | bash
cp /root/.bun/bin/bun /usr/local/bin/bun
chmod +x /usr/local/bin/bun

# 4. Install iii (Try official installer first)
echo "[+] Installing iii..."
curl -fsSL https://install.iii.dev/iii/main/install.sh | sh || echo "Official installer failed, trying fallback..."

# Find where it went
III_BIN=$(which iii || find /usr -name iii -type f | head -n 1 || echo "/usr/local/bin/iii")

# Fallback: Direct Download if missing or tiny (corrupted)
if [ ! -f "$III_BIN" ] || [ $(stat -c%s "$III_BIN") -lt 1000 ]; then
  echo "[!] iii binary missing or corrupted, downloading directly..."
  curl -Lo /usr/local/bin/iii https://github.com/Alchemyst-ai/hiring/releases/download/v0.11.0/iii-linux-amd64
  chmod +x /usr/local/bin/iii
  III_BIN="/usr/local/bin/iii"
fi

# Ensure it's exactly where the service expects it
if [ "$III_BIN" != "/usr/local/bin/iii" ]; then
  cp "$III_BIN" /usr/local/bin/iii
  chmod +x /usr/local/bin/iii
fi

# FINAL VALIDATION
if ! /usr/local/bin/iii --version; then
  echo "FATAL: iii binary is not working"
  exit 1
fi

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
