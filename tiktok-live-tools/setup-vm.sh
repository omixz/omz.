#!/usr/bin/env bash
# One-time setup on a fresh Ubuntu server (e.g. Oracle Cloud Always Free VM).
# Usage:  bash setup-vm.sh      (run it again any time to update to the latest version)
set -euo pipefail
REPO=${REPO:-https://github.com/omixz/omz..git}
BRANCH=${BRANCH:-main}
cd "$HOME"

if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER" || true
fi
sudo systemctl enable --now docker

# Oracle's Ubuntu images block incoming ports with iptables: open web (80/443) and the hub's fallback port.
for port in 80 443 3000; do
  if command -v iptables >/dev/null && ! sudo iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT -p tcp --dport $port -j ACCEPT
  fi
done
command -v netfilter-persistent >/dev/null && sudo netfilter-persistent save >/dev/null 2>&1 || true

if [ -d omz/.git ]; then git -C omz pull --ff-only; else git clone --depth 1 -b "$BRANCH" "$REPO" omz; fi
cd omz/tiktok-live-tools

if [ ! -f .env ]; then
  cp .env.example .env
  rand() { openssl rand -hex 16; }
  sed -i "s/^ADMIN_KEY=.*/ADMIN_KEY=$(rand)/; s/^RCON_PASSWORD=.*/RCON_PASSWORD=$(rand)/" .env
  read -rp "Your TikTok username (without @): " TT </dev/tty
  sed -i "s/^TIKTOK_USERNAME=.*/TIKTOK_USERNAME=${TT#@}/" .env
  echo
  echo "Minecraft needs you to accept Mojang's EULA: https://aka.ms/MinecraftEULA"
  read -rp "Do you accept the Minecraft EULA? (y/N) " EULA </dev/tty
  if [[ "$EULA" =~ ^[Yy] ]]; then
    sed -i "s/^MINECRAFT_EULA=.*/MINECRAFT_EULA=TRUE/" .env
  else
    echo "OK: Minecraft stays off, the stream will show Castle Clash instead."
    sed -i "s/^COMPOSE_PROFILES=minecraft/# COMPOSE_PROFILES=minecraft/; s/^MC_HOST=/# MC_HOST=/; s#^GAME_PATH=.*#GAME_PATH=/game#" .env
  fi
fi

# Your hub's https:// address: <ip-with-dashes>.sslip.io points at this server for free.
IP=$(curl -fs4 ifconfig.me || curl -fs4 api.ipify.org || echo "")
if [ -n "$IP" ] && ! grep -q '^SITE_ADDRESS=' .env; then
  echo "SITE_ADDRESS=${IP//./-}.sslip.io" >> .env
fi
SITE=$(grep '^SITE_ADDRESS=' .env | cut -d= -f2)

sudo docker compose up -d --build
echo
echo "✅ Running, and it restarts by itself after crashes and reboots."
echo "   Your hub (open on your phone, add to home screen):"
echo "      https://${SITE:-$IP}"
echo "      (if that doesn't load within a few minutes: http://$IP:3000)"
echo "   Password:   $(grep '^ADMIN_KEY=' .env | cut -d= -f2)"
echo "   Next: in the hub, paste your TikTok Server URL + Stream key, then press Go LIVE in TikTok LIVE Producer."
