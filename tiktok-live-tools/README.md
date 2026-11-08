# TikTok LIVE Tools

A lightweight TikTok LIVE interaction tool, similar to TikFinity, that **doesn't need a gaming PC**.
It's one small Node.js server (≈60 MB of RAM, almost no CPU) that you can run on a **free cloud host**, an old laptop, a Raspberry Pi or even an old Android phone. You control everything from your phone's browser.

## What it does

| Feature | Details |
|---|---|
| 🎁 Gift / follow / share alerts | On-screen pop-ups with the gift picture, a sound and an optional spoken thank-you |
| ⚡ Actions | Triggered by: a gift (any gift, a gift by name, or a coin range), a follow, a share, every N likes, a chat command (`!dance`), a word in chat, or a viewer joining. Each action can show an alert, play a sound, speak text and have a cooldown |
| 🗣 Text-to-speech | Reads chat (all messages, or only `!tts …`), with a blocked-words list, link filter, length limit and voice/speed/pitch picker. Free: it uses your device's built-in voices |
| 📊 Live stats | Viewers, likes, coins, follows, shares and gifts, plus a live feed that shows gift combos as they build |
| 🖼 OBS / LIVE Studio overlays | Alerts, chat, goal bar and top gifters (transparent browser sources) |
| 🔁 Auto-connect | Leave it running. It checks about once a minute and connects as soon as you go live, then reconnects if the connection drops |
| 🧪 Test buttons | Fake gifts, follows, likes and chat so you can set things up without being live |
| 🔒 Admin key | Only you can control the dashboard. Overlays stay public and read-only |

## Option A: free cloud hosting with Render (no computer needed)

1. Create a free account at [render.com](https://render.com) and connect your GitHub.
2. In Render, click **New → Blueprint** and choose this repository. Render reads `render.yaml` and sets everything up.
3. When it asks for `TIKTOK_USERNAME`, enter your TikTok username without the `@`.
4. Once it's deployed, open the service's **Environment** tab and copy the generated **`ADMIN_KEY`**.
5. Open your app URL (e.g. `https://tiktok-live-tools-xxxx.onrender.com`) on your phone and enter the admin key. Then **Add to Home Screen** so it works like an app.

**Free-plan notes**
- Render's free plan **goes to sleep after 15 minutes without visits**, and a sleeping server can't auto-connect. To keep it awake, create a free monitor at [uptimerobot.com](https://uptimerobot.com) that opens `https://YOUR-APP.onrender.com/healthz` every 5 minutes.
- The free plan can wipe saved files when it restarts. Your dashboard keeps a backup of your settings in your browser and restores it automatically. You can also use **Settings → Export**.

Other hosts work the same way: [Railway](https://railway.app), [Fly.io](https://fly.io) and [Koyeb](https://koyeb.com) can use the included `Dockerfile`. Set the service's root directory to `tiktok-live-tools`.

## Option B: an old phone, laptop or Raspberry Pi

You need Node.js 20 or newer.

```bash
cd tiktok-live-tools
npm install
ADMIN_KEY=pick-a-password TIKTOK_USERNAME=yourname npm start
```

Then open `http://<that-device's-IP>:3000` from your phone on the same Wi-Fi.

**On an Android phone**, install [Termux](https://f-droid.org/packages/com.termux/) from F-Droid, then run:
`pkg install nodejs git`, `git clone <this repo>`, then the commands above. Keep Termux open (use "Acquire wakelock" from its notification).

## How to use it while streaming

**If you stream from your phone with the TikTok app** (TikTok's app doesn't allow overlays):
- Open the dashboard on a **second device** (an old phone or tablet is fine) placed near your streaming phone, or connected to a speaker.
- In the **TTS** tab, turn on *Speak TTS on this device* and *Play alert sounds on this device*. Your viewers will hear the TTS and alert sounds through your mic.
- Optionally, point your camera at that device's screen with `/overlay/alerts` open full-screen. Your viewers then see the pop-ups in your stream.

**If you stream with OBS or TikTok LIVE Studio** (any basic laptop can run these when you aren't gaming):
- Go to the **Overlays** tab, copy a link and add it as a **Browser Source** (OBS) or **Link** source (LIVE Studio). Suggested size: 1080×1920 for portrait.
- In OBS, tick **"Control audio via OBS"** on the alerts source so its sounds reach your stream.
- Speech (TTS) often doesn't work inside OBS. Keep the dashboard open in Chrome on the same PC with *Speak TTS on this device* on, and capture that audio. You can also try the `/overlay/alerts?tts=1` link.

### Overlay URL options
- `/overlay/alerts`: `?sound=0` mutes sounds, `?tts=1` speaks inside the overlay, `?volume=0.5`, `?scale=1.5`
- `/overlay/chat`: `?max=10` sets how many messages show, `?fade=30` fades messages after 30 seconds, `?gifts=0`, `?follows=0`, `?size=24` sets the font size
- `/overlay/top`: `?n=5` sets how many gifters show, `?title=Legends`
- `/overlay/goal`: the goal type, target and title are set in the dashboard

### Text placeholders for actions
`{user}` `{username}` `{gift}` `{count}` `{coins}` `{comment}` `{args}` (the text after a command) `{totalLikes}` `{viewers}`

## Environment variables

| Variable | Purpose |
|---|---|
| `PORT` | Port to listen on (default `3000`) |
| `ADMIN_KEY` | Password for the dashboard. **Set this on any public host.** |
| `TIKTOK_USERNAME` | Username to auto-connect to on startup |
| `DATA_DIR` | Where `settings.json` is stored (default `./data`) |
| `SIGN_API_KEY` | Optional free key from [eulerstream.com](https://www.eulerstream.com). The TikTok connection library uses this signing service, and a key raises its rate limits if you see "rate limit" errors |

## How it works

```
TikTok LIVE ──(tiktok-live-connector)──▶ server.js ──(Socket.IO)──▶ dashboard (phone)
                                            │                    ├▶ /overlay/alerts
                                            │ rules, TTS filter, ├▶ /overlay/chat
                                            │ stats, leaderboard ├▶ /overlay/goal
                                            ▼                    └▶ /overlay/top
                                     data/settings.json
```

TikTok has no official API for LIVE events. This tool uses the community library [`tiktok-live-connector`](https://github.com/zerodytrash/TikTok-Live-Connector), the same approach most tools like this use. If TikTok changes something, run `npm update tiktok-live-connector` to get the fix.
