# TikTok LIVE Tools: Castle Clash

An interactive TikTok LIVE game where **likes and gifts control the action**. It's designed to run **24/7 on its own**, with no gaming PC and nothing for you to touch.

## 🏰 The game: Castle Clash

Two teams, two castles:

| Viewer does | What happens on screen |
|---|---|
| Comments **1** or **2** | Joins team RED or BLUE (anyone who doesn't pick is put on the smaller team) |
| ❤️ Taps likes | Every 5 likes sends a **soldier** with the viewer's profile picture |
| 🌹 Gift worth 1+ coins | A **Knight** for each gift (a 5x Rose combo sends 5 knights) |
| 🎁 Gift worth 10+ coins | A **Giant** |
| 🐉 Gift worth 99+ coins | A **Dragon** that flies over the battle, burns enemies and smashes the castle |
| ☄️ Gift worth 500+ coins | A **Meteor** that wipes out every enemy unit and hits the enemy castle hard |
| ➕ Follows / 🔁 shares | 2 knights / 5 soldiers |

When a castle falls, the game shows the winning team and the **top 3 fighters**, then the next round starts by itself. The rules are always shown on screen, so viewers know what to do. You can change every number (team names, join words, prices, castle health) from your phone in the dashboard's **Game** tab.

Want to see it without being live? Open `/game?demo=1` for a preview with fake viewers.

---

## 🤖 Hands-free 24/7 mode (recommended)

A small always-on server runs the game in a hidden browser and **streams it straight to TikTok** with your stream key. Your phone and laptop aren't involved.

```
TikTok LIVE events ─▶ server ─▶ game in a virtual screen ─▶ ffmpeg ─▶ TikTok (RTMP stream key)
```

Every part restarts itself if it crashes, and Docker restarts everything after a reboot.

### What you need
1. **A TikTok stream key.** Open [TikTok LIVE Producer](https://livecenter.tiktok.com/producer). If your account has it, you'll see a **Server URL** and a **Stream key**. TikTok decides which accounts get this; it often depends on followers or region.
2. **A free always-on server.** [Oracle Cloud "Always Free"](https://www.oracle.com/cloud/free/) gives you an *Ampere A1* VM (up to 4 CPUs and 24 GB of RAM) at no cost, which is plenty for streaming at 720p. Sign-up asks for a card to verify your identity, but Always Free resources aren't charged. Any old non-gaming PC running Linux with Docker works too.

### Setup (one time, about 15 minutes)
1. Create an **Ubuntu** VM on Oracle (shape **VM.Standard.A1.Flex**, 2–4 OCPUs). In its *Virtual Cloud Network → Security List*, add an ingress rule for **TCP port 3000**.
2. SSH into it and run:
   ```bash
   git clone https://github.com/omixz/omz..git omz   # private repo? use a GitHub token in the URL
   bash omz/tiktok-live-tools/setup-vm.sh
   nano omz/tiktok-live-tools/.env                  # your username, a password (ADMIN_KEY), optionally the stream key
   bash omz/tiktok-live-tools/setup-vm.sh            # builds and starts everything
   ```
3. On your phone, open `http://YOUR-SERVER-IP:3000` and enter your password. Go to **Settings → Cloud streaming** and paste the Server URL and Stream key. That's it.

### What still needs you (TikTok's rules, not this tool's)
- **Starting the LIVE.** TikTok doesn't let any tool go live for you. In LIVE Producer, press **Go LIVE** once; the game feed is already arriving. While you aren't live, TikTok simply ignores the feed.
- **A new stream key.** If TikTok gives you a new key for a LIVE, paste it in the dashboard. The server switches within about 5 seconds, with no restart.
- **TikTok's LIVE guidelines.** Interactive game streams are popular, but TikTok can limit or flag LIVEs it sees as unattended or repetitive. Hosting now and then and replying to chat helps keep the stream healthy.

---

## Other ways to run it

### Stream from your phone
Open `https://YOUR-SERVER/game` on your phone and start a TikTok **screen-share / mobile gaming LIVE**. The game starts by itself, keeps the screen awake and reconnects on its own. For this you only need the lightweight server below, not the streaming VM.

### OBS / TikTok LIVE Studio
Add `/game` as a Browser Source (1080×1920 or 720×1280). Add `?bg=transparent` to put it over your camera.

### Lightweight server only (no built-in streaming)
For phone or OBS streaming you only need the small app server. It runs fine on Render's free plan: **New → Blueprint** with this repo uses `render.yaml`. Free Render servers sleep after 15 minutes without visits; a free [UptimeRobot](https://uptimerobot.com) monitor on `/healthz` every 5 minutes keeps it awake. Locally: `npm install && ADMIN_KEY=secret TIKTOK_USERNAME=you npm start`.

---

## Also included
- **Dashboard** (`/`): live feed, stats, test buttons (no need to be live) and settings. It works from your phone.
- **Alert actions:** gift, follow, share, likes and chat commands can show a pop-up, play a sound and speak text.
- **Text-to-speech** for chat (all messages, or only `!tts …`), with blocked words.
- **Overlays:** `/overlay/alerts`, `/overlay/chat`, `/overlay/goal` and `/overlay/top`.
- **Auto-connect:** the server checks about once a minute and connects to your LIVE as soon as it starts.

## Environment variables

| Variable | Purpose |
|---|---|
| `TIKTOK_USERNAME` | Your TikTok username (no `@`) |
| `ADMIN_KEY` | Dashboard password. **Always set this on a public server.** |
| `STREAM_URL`, `STREAM_KEY` | Optional. The stream key can be set in the dashboard instead. |
| `STREAM_BITRATE`, `STREAM_FPS`, `STREAM_WIDTH`, `STREAM_HEIGHT` | Stream quality (default 2500k, 30 fps, 720×1280) |
| `PORT`, `DATA_DIR` | Defaults: `3000`, `./data` |
| `SIGN_API_KEY` | Optional free key from [eulerstream.com](https://www.eulerstream.com). It raises rate limits for the TikTok connection library. |

TikTok has no official API for LIVE events. This tool uses the community library [`tiktok-live-connector`](https://github.com/zerodytrash/TikTok-Live-Connector). If TikTok changes something, rebuild with the latest version: `docker compose build --no-cache && docker compose up -d`.
