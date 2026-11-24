#!/usr/bin/env bash
# One-time setup on a fresh Ubuntu server (any provider: Hetzner, DigitalOcean, Vultr, Linode, Oracle…).
# Usage:  bash setup-vm.sh      (run it again any time to update to the latest version)
#
# Asks two questions when run in a terminal. To run with no questions (e.g. from
# cloud-init.yaml), set these first:
#   TIKTOK_USERNAME=yourname  ADMIN_KEY=your-hub-password  ACCEPT_MINECRAFT_EULA=yes
set -euo pipefail
REPO=${REPO:-https://github.com/omixz/omz..git}
BRANCH=${BRANCH:-main}
export HOME=${HOME:-/root}
cd "$HOME"

if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "${USER:-$(id -un)}" || true
fi
sudo systemctl enable --now docker

# Some images (e.g. Oracle's Ubuntu) block incoming ports with iptables: open web (80/443) and the hub's fallback port.
for port in 80 443 3000; do
  if command -v iptables >/dev/null && ! sudo iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null; then
    sudo iptables -I INPUT -p tcp --dport $port -j ACCEPT
  fi
done
command -v netfilter-persistent >/dev/null && sudo netfilter-persistent save >/dev/null 2>&1 || true

if [ -d omz/.git ]; then git -C omz pull --ff-only; else git clone --depth 1 -b "$BRANCH" "$REPO" omz; fi
cd omz/tiktok-live-tools

# set_env KEY VALUE: safe for any characters in VALUE (no sed escaping problems)
set_env() {
  local tmp; tmp=$(mktemp)
  grep -v "^$1=" .env > "$tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$tmp"
  mv "$tmp" .env
}
# ask "question" -> reads from the terminal if there is one, else prints nothing
ask() {
  local answer=''
  if { exec 3</dev/tty; } 2>/dev/null; then read -r -u 3 -p "$1" answer || true; exec 3<&-; fi
  printf '%s' "$answer"
}

if [ ! -f .env ]; then
  cp .env.example .env
  rand() { openssl rand -hex 16; }
  set_env RCON_PASSWORD "$(rand)"
  set_env ADMIN_KEY "${ADMIN_KEY:-$(rand)}"
  TT=${TIKTOK_USERNAME:-$(ask "Your TikTok username (without @): ")}
  [ -n "$TT" ] && set_env TIKTOK_USERNAME "${TT#@}"
  EULA=${ACCEPT_MINECRAFT_EULA:-}
  if [ -z "$EULA" ]; then
    echo
    echo "Minecraft needs you to accept Mojang's EULA: https://aka.ms/MinecraftEULA"
    EULA=$(ask "Do you accept the Minecraft EULA? (y/N) ")
  fi
  if [[ "$EULA" =~ ^([Yy]|[Tt]rue|TRUE) ]]; then
    set_env MINECRAFT_EULA TRUE
  else
    echo "OK: Minecraft stays off, the stream will show Castle Clash instead."
    sed -i "s/^COMPOSE_PROFILES=minecraft/# COMPOSE_PROFILES=minecraft/; s/^MC_HOST=/# MC_HOST=/; s#^GAME_PATH=.*#GAME_PATH=/game#" .env
  fi
fi

# Your hub's https:// address: <ip-with-dashes>.sslip.io points at this server for free.
IP=$(curl -fs4 ifconfig.me || curl -fs4 api.ipify.org || echo "")
if [ -n "$IP" ] && ! grep -q '^SITE_ADDRESS=' .env; then
  set_env SITE_ADDRESS "${IP//./-}.sslip.io"
fi
SITE=$(grep '^SITE_ADDRESS=' .env | cut -d= -f2 || true)

sudo docker compose up -d --build
echo
echo "✅ Running, and it restarts by itself after crashes and reboots."
echo "   Your hub (open on your phone, add to home screen):"
echo "      https://${SITE:-$IP}"
echo "      (if that doesn't load within a few minutes: http://$IP:3000)"
echo "   Password:   $(grep '^ADMIN_KEY=' .env | cut -d= -f2-)"
echo "   Next: in the hub, paste your TikTok Server URL + Stream key, then press Go LIVE in TikTok LIVE Producer."
