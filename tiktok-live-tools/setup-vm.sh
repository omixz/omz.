#!/usr/bin/env bash
# One-time setup on a fresh Ubuntu server (e.g. Oracle Cloud Always Free VM).
# Usage:  curl -fsSL <raw url of this file> | bash      (or: bash setup-vm.sh)
set -euo pipefail
REPO=${REPO:-https://github.com/omixz/omz..git}
BRANCH=${BRANCH:-main}
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER" || true
fi
sudo systemctl enable --now docker
# Oracle's Ubuntu images block incoming ports with iptables: open the dashboard port.
if command -v iptables >/dev/null && ! sudo iptables -C INPUT -p tcp --dport 3000 -j ACCEPT 2>/dev/null; then
  sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
  command -v netfilter-persistent >/dev/null && sudo netfilter-persistent save || true
fi
[ -d omz ] || git clone --depth 1 -b "$BRANCH" "$REPO" omz
cd omz/tiktok-live-tools
if [ ! -f .env ]; then
  cp .env.example .env
  echo; echo ">>> Now edit tiktok-live-tools/.env (nano .env) with your username, password and stream key, then run:"
  echo "    cd $(pwd) && sudo docker compose up -d --build"
  exit 0
fi
sudo docker compose up -d --build
echo "Running. Dashboard: http://$(curl -fs ifconfig.me || echo YOUR-SERVER-IP):3000"
