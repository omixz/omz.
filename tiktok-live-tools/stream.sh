#!/usr/bin/env bash
# Hands-free mode: runs the server, opens the game in a virtual screen and
# streams it (video + game sound) to TikTok over RTMP. Every part restarts
# itself if it crashes, so it can run 24/7 without anyone touching it.
#
# Stream key: paste it in the dashboard (Settings -> Cloud streaming), or set
#   STREAM_URL + STREAM_KEY, or STREAM_TARGET (full rtmp://... URL, or a .mp4 path for testing)
# Optional: STREAM_WIDTH (720) STREAM_HEIGHT (1280) STREAM_FPS (30) STREAM_BITRATE (2500k)
#           GAME_PATH (/game; use /minecraft for the Minecraft hero) — any page of the app
#           GAME_CMD  run any other real game instead of a page, e.g. GAME_CMD="supertux2 --fullscreen"
#           MC_HOST   when set, also starts the Minecraft bridge (bot + camera + RCON), see docker-compose.yml
set -u
cd "$(dirname "$0")"

W=${STREAM_WIDTH:-720}
H=${STREAM_HEIGHT:-1280}
FPS=${STREAM_FPS:-30}
VBR=${STREAM_BITRATE:-2500k}
PORT=${PORT:-3000}
GAME_PATH=${GAME_PATH:-/game}
DISP=${STREAM_DISPLAY:-:99}
CHROME=${CHROME_BIN:-$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)}
RUN_DIR=$(mktemp -d)
log() { echo "[stream] $*"; }

DATA_DIR=${DATA_DIR:-./data}
STREAM_FILE="$DATA_DIR/stream.json"   # written by the dashboard (Settings -> Cloud streaming)

# Where to send the video: dashboard setting first, then environment variables.
target() {
  if [ -n "${STREAM_TARGET:-}" ]; then echo "$STREAM_TARGET"; return; fi
  if [ -f "$STREAM_FILE" ]; then
    local t
    t=$(node -e 'try{const s=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));if(s.url&&s.key)console.log(s.url.replace(/\/+$/,"")+"/"+s.key)}catch{}' "$STREAM_FILE")
    if [ -n "$t" ]; then echo "$t"; return; fi
  fi
  if [ -n "${STREAM_URL:-}" ] && [ -n "${STREAM_KEY:-}" ]; then echo "${STREAM_URL%/}/${STREAM_KEY}"; fi
}
mtime() { stat -c %Y "$STREAM_FILE" 2>/dev/null || echo 0; }

cleanup() { trap - INT TERM; log "shutting down"; rm -rf "$RUN_DIR"; kill 0 2>/dev/null; exit 0; }
trap cleanup INT TERM

# 1) the app server (restarts if it crashes)
( while true; do node server.js; log "server exited, restarting in 3s"; sleep 3; done ) &

# 2) a virtual screen exactly the size of the stream
Xvfb "$DISP" -screen 0 "${W}x${H}x24" -nolisten tcp >/dev/null 2>&1 &
export DISPLAY=$DISP

# 3) a virtual sound card so the game's sounds go into the stream
AUDIO_IN=(-f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100")   # silent fallback
export PULSE_RUNTIME_PATH="$RUN_DIR/pulse"
if command -v pulseaudio >/dev/null && pulseaudio -D --exit-idle-time=-1 --disallow-exit -n \
     --load="module-null-sink sink_name=game" --load="module-native-protocol-unix" >/dev/null 2>&1; then
  sleep 1
  pactl set-default-sink game >/dev/null 2>&1 && AUDIO_IN=(-f pulse -i game.monitor) && log "game audio: on"
else
  log "game audio: unavailable, streaming silence"
fi

# wait for the server
for _ in $(seq 1 60); do curl -fs "http://localhost:$PORT/healthz" >/dev/null 2>&1 && break; sleep 1; done

# 3b) Minecraft: the hero bot, its 3D camera and the command runner (restarts if it crashes)
if [ -n "${MC_HOST:-}" ] && [ -f minecraft/bridge.js ]; then
  ( cd minecraft && while true; do APP_URL="http://localhost:$PORT" node bridge.js; log "minecraft bridge exited, restarting in 10s"; sleep 10; done ) &
fi

# 4) the game, full screen, sound allowed without a click (restarts if it crashes).
#    WebGL runs on the CPU (SwiftShader) so 3D games like the Minecraft camera work without a GPU.
if [ -n "${GAME_CMD:-}" ]; then
  ( while true; do bash -c "$GAME_CMD"; log "game exited, restarting in 3s"; sleep 3; done ) &
else
if [ -z "$CHROME" ]; then log "no Chromium found: set CHROME_BIN"; exit 1; fi
( while true; do
    "$CHROME" --no-sandbox --no-first-run --no-default-browser-check --disable-dev-shm-usage \
      --use-angle=swiftshader --enable-unsafe-swiftshader --ignore-gpu-blocklist \
      --kiosk --app="http://localhost:$PORT$GAME_PATH" --window-position=0,0 --window-size="$W,$H" \
      --autoplay-policy=no-user-gesture-required --noerrdialogs --disable-infobars \
      --disable-session-crashed-bubble --disable-features=Translate,MediaRouter \
      --user-data-dir="$RUN_DIR/chrome" >/dev/null 2>&1
    log "browser exited, restarting in 3s"; sleep 3
  done ) &
fi

# 5) send it to TikTok. Reconnects forever: while you're not LIVE, TikTok simply
#    ignores the feed. If you paste a new stream key in the dashboard, it switches.
sleep 4
while true; do
  TARGET=$(target)
  if [ -z "$TARGET" ]; then
    log "no stream key yet: add it in the dashboard (Settings -> Cloud streaming). The game is running meanwhile."
    while [ -z "$(target)" ]; do sleep 10; done
    continue
  fi
  M=$(mtime)
  log "streaming ${W}x${H}@${FPS}fps to ${TARGET%/*}/****"
  OUT_FMT=(-f flv); case "$TARGET" in *.mp4|*.mkv) OUT_FMT=();; esac
  ffmpeg -hide_banner -loglevel warning -nostdin \
    -thread_queue_size 512 -f x11grab -draw_mouse 0 -video_size "${W}x${H}" -framerate "$FPS" -i "$DISP" \
    -thread_queue_size 512 "${AUDIO_IN[@]}" \
    -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p \
    -b:v "$VBR" -maxrate "$VBR" -bufsize "$VBR" -g $((FPS * 2)) \
    -c:a aac -b:a 128k -ar 44100 -ac 2 \
    ${STREAM_SECONDS:+-t "$STREAM_SECONDS"} "${OUT_FMT[@]}" "$TARGET" &
  FF=$!
  while kill -0 "$FF" 2>/dev/null; do
    sleep 5
    if [ "$(mtime)" != "$M" ]; then log "stream key changed in the dashboard, switching"; kill "$FF" 2>/dev/null; fi
  done
  wait "$FF" 2>/dev/null
  [ -n "${STREAM_SECONDS:-}" ] && { log "test recording finished"; cleanup; }
  log "stream stopped, reconnecting in 5s"; sleep 5
done
