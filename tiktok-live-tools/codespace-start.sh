#!/usr/bin/env bash
# Starts the Steve LIVE test drive inside a GitHub Codespace (runs automatically on start).
# For testing only: use a real server (cloud-init.yaml) for public live streams.
#
#   bash tiktok-live-tools/codespace-start.sh --accept-eula   # accept https://aka.ms/MinecraftEULA and start Minecraft
set -euo pipefail
cd "$(dirname "$0")"

set_env() { local tmp; tmp=$(mktemp); grep -v "^$1=" .env > "$tmp" || true; printf '%s=%s\n' "$1" "$2" >> "$tmp"; mv "$tmp" .env; }

echo "⏳ Waiting for Docker…"
for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 2; done

if [ ! -f .env ]; then
  cp .env.example .env
  set_env ADMIN_KEY ""                       # the Codespace port is already private to your GitHub account
  set_env RCON_PASSWORD "$(openssl rand -hex 16)"
  set_env MINECRAFT_MEMORY 3G                # fits the 8 GB Codespace
fi
[ -n "${TIKTOK_USERNAME:-}" ] && set_env TIKTOK_USERNAME "${TIKTOK_USERNAME#@}"
if [ "${1:-}" = "--accept-eula" ] || [[ "${MINECRAFT_EULA:-}" =~ ^(TRUE|true|True|yes|y)$ ]]; then
  set_env MINECRAFT_EULA TRUE
fi

if grep -q '^MINECRAFT_EULA=TRUE' .env; then
  set_env COMPOSE_PROFILES minecraft; set_env MC_HOST minecraft; set_env GAME_PATH /minecraft
  export MINECRAFT_EULA=TRUE   # docker compose reads this before .env; the Minecraft image wants exactly TRUE
  SERVICES="live minecraft"
else
  set_env COMPOSE_PROFILES ""; set_env MC_HOST ""; set_env GAME_PATH /game
  export MINECRAFT_EULA=FALSE
  SERVICES="live"
  echo
  echo "ℹ️  Minecraft is off until you accept its EULA (https://aka.ms/MinecraftEULA). To accept and start it, run:"
  echo "      bash tiktok-live-tools/codespace-start.sh --accept-eula"
fi

echo "🔨 Building and starting (first time takes ~5–10 minutes)…"
docker compose up -d --build $SERVICES
echo
echo "✅ Steve LIVE is starting. Open the PORTS tab → port 3000 (\"Steve LIVE Hub\")."
echo "   Watch the game at <that address>/minecraft, test gifts with the hub's test buttons."
echo "   Minecraft needs ~2 minutes after this to create its world before Steve joins."
