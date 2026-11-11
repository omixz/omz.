# TikTok LIVE Tools

Interactive TikTok LIVE games where **viewers' likes and gifts control the action**. They run **24/7 on a free cloud server**, with no gaming PC and nothing for you to touch.

| Game | What it is |
|---|---|
| ⛏️ **Minecraft: Can Steve Survive?** (`/minecraft`) | A **real Minecraft server**, streamed in **first person**. Viewers' likes and gifts send zombies, creepers, TNT and boss raids, named after them, at Steve. He fights back on his own and levels up. Round wins are credited to viewers, with a banner and a leaderboard. |
| 🏰 **Castle Clash** (`/game`) | A two-team battle that runs in a browser. Viewers comment 1 or 2 to pick a team, likes send soldiers, gifts send knights, giants, dragons and meteors. |
| 🎮 **Any other game** | Actions can **press keys** in any game running on the stream server, and `GAME_CMD` streams any Linux game instead of a web page. |

---

## ⛏️ Minecraft: Can Steve Survive?

A survival challenge in a **real Minecraft world**, streamed **in first person through Steve's eyes**. Every like, follow, share and gift sends a mob at Steve, **named after the viewer who sent it**. Steve **fights them off on his own**:
- he attacks the nearest monster
- he eats when hurt
- he backs off when he's nearly out of health and has no food

The longer Steve survives, the more he **levels up**, getting better gear every 2½ minutes:

| Level | Gear |
|---|---|
| 1 | Iron (what he respawns with) |
| 2 | Diamond sword |
| 3 | Diamond armor |
| 4 | Full diamond |
| 5 | Netherite |

At higher levels viewers need bigger gifts. When Steve falls, Minecraft's own message ("Steve was slain by Mia") names the mob that did it, and since mobs carry viewer names, **that viewer wins the round**. The stream then shows:
- a big **"ROUND WON BY MIA!"** banner
- a **Top challengers** leaderboard, saved so it survives restarts
- the round number, survival timer and record
- a **❤️ likes progress bar** ("63 / 100 → 🧟 Zombie")
- a feed of who sent what, with profile pictures
- a legend of what every gift does

The wording deliberately avoids violent terms so it fits TikTok's LIVE guidelines.

```
TikTok gifts ─▶ LIVE Tools ─▶ RCON commands ─▶ real Minecraft server (Paper 1.21.4, private)
                                                     ▲
             bot player "Steve" ─────────────────────┘  fights on his own, eats, levels up, respawns
             first-person 3D camera (prismarine-viewer) ─▶ /minecraft page ─▶ ffmpeg ─▶ TikTok
```

**Default actions.** They switch on by themselves the first time Steve joins, and you can edit them in the dashboard's **Actions** tab.

| Viewers send | Steve gets (named after the viewer) |
|---|---|
| ❤️ Every 100 likes | 🧟 Zombie |
| Gift 1–4 🪙 (Rose…) | 🧟 Zombie, one per gift in a combo |
| Gift 5–9 🪙 | 🏹 Skeleton archer |
| Gift 10–19 🪙 | 🕷️ Spider |
| Gift 20–29 🪙 | 🏃 2 speedy baby zombies |
| Gift 30–49 🪙 | 💥 Creeper |
| Gift 50–98 🪙 | 🧪 Witch + poison |
| Gift 99–198 🪙 | 🛡️ 3 armored zombies |
| Gift 199–298 🪙 | 🧨 TNT rain |
| Gift 299–498 🪙 | 🪓 Vindicator gang |
| Gift 499–998 🪙 | 🐗 Ravager |
| Gift 999–1998 🪙 | 👹 Boss raid (lightning, ravager, vindicators, evoker) |
| Gift 1999+ 🪙 | 🌑 THE WARDEN |
| Follow / Share / chat `!zombie` | 🧟 Zombie / 🏹 Skeleton / 🧟 Zombie |

**Each round starts fresh**: leftover mobs are cleared when Steve respawns, and mobs are capped at 60 (`MC_MOB_CAP`) so gift storms can't lag the stream. **Built to run for days.** Only viewers spawn mobs, and a lone zombie wanders in when chat is quiet so the stream never looks frozen. Creepers don't break blocks, and TNT holes are repaired every minute. Dropped items are cleared, and a world border keeps everything on camera. The bot, camera, server and stream all restart themselves. Tune it with `MC_BOT_NAME`, `MC_FIRST_PERSON=0` (camera behind Steve instead), `MC_LEVEL_UP_SECONDS` (150, 0 = off), `MC_RESPAWN_KIT` and `MC_ARENA_RADIUS`.

**Write your own actions.** Any action can run Minecraft commands, one per line. Placeholders:
- `{bot}`: Steve
- `{user}`: the viewer's name, cleaned so it can't break a command
- `{rx}` `{rz}`: a random spot 3–7 blocks away
- `{count}`, `{coins}`, `{gift}`: details of the gift

Example: `execute at {bot} run summon minecraft:zombie ~{rx} ~1 ~{rz} {CustomName:'"{user}"',CustomNameVisible:1b}`. The **Game** tab also has a box for running a command right away.

> Running a Minecraft server means accepting [Mojang's EULA](https://aka.ms/MinecraftEULA); the setup asks you. The server is private (no port is opened), so it runs in offline mode, which lets the bot join without a Microsoft account.

---

## 🤖 Setup: hands-free 24/7 (one time, about 15 minutes)

### What you need
1. **A TikTok stream key.** Open [TikTok LIVE Producer](https://livecenter.tiktok.com/producer). If your account has it, you'll see a **Server URL** and a **Stream key**. TikTok decides which accounts get this; it often depends on followers or region.
2. **A free always-on server.** [Oracle Cloud "Always Free"](https://www.oracle.com/cloud/free/) gives you an **Ampere A1** VM with up to 4 CPUs and 24 GB of RAM at no cost, enough for Minecraft plus 720p streaming. Use **4 OCPUs and 24 GB** for Minecraft. Sign-up asks for a card to verify your identity, but Always Free resources aren't charged. Any old non-gaming PC running Linux with Docker works too.

### Steps
1. Create an **Ubuntu** VM on Oracle (shape **VM.Standard.A1.Flex**). In its *Virtual Cloud Network → Security List*, add ingress rules for **TCP 80** and **TCP 443** (your hub's https address) and **TCP 3000** (fallback).
2. SSH into the VM and run one command. It asks for your TikTok username and the Minecraft EULA, generates the passwords, then builds and starts everything:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/omixz/omz./main/tiktok-live-tools/setup-vm.sh | bash
   ```
   (If the repo is private, clone it first with a GitHub token, then run `bash omz/tiktok-live-tools/setup-vm.sh`.)
3. Open the **hub** address it prints on your phone, e.g. `https://129-146-12-34.sslip.io`, a free https address that points at your server (made with [sslip.io](https://sslip.io) and [Caddy](https://caddyserver.com), no domain needed). Add it to your home screen. Enter the password it prints, then paste the Server URL and Stream key in **Setup**. The hub shows three status lights (TikTok, Minecraft, stream), a **Watch what viewers see** button, the gift ladder and test buttons. Everything else is under **Advanced settings**.

Run the same command again any time to update.

### What still needs you (TikTok's rules, not this tool's)
- **Starting the LIVE.** TikTok doesn't let any tool go live for you. In LIVE Producer, press **Go LIVE**; the game feed is already arriving. While you aren't live, TikTok ignores it.
- **A new stream key.** If TikTok gives you a new key, paste it in the dashboard. The server switches within about 5 seconds.
- **TikTok's LIVE guidelines.** TikTok can limit LIVEs it sees as unattended or repetitive. Hosting now and then and replying to chat helps.

### Switching games
Set `GAME_PATH` in `tiktok-live-tools/.env`, then run `sudo docker compose up -d`:
- `GAME_PATH=/minecraft`: Minecraft, Can Steve Survive? (default)
- `GAME_PATH=/game`: Castle Clash. Remove `COMPOSE_PROFILES=minecraft` to turn the Minecraft server off.
- `GAME_CMD="some-game --fullscreen"`: any Linux game instead of a web page. Install it in `Dockerfile.streamer`, then use **key presses** in Actions (e.g. `space`, `Left Left Up`) so likes and gifts control it. Without a GPU, 2D and light 3D games work best.

---

## Other ways to run it
- **Stream from your phone:** open `https://YOUR-SERVER/game` (or `/minecraft`) and start a TikTok screen-share LIVE.
- **OBS / LIVE Studio:** add `/minecraft`, `/game` or any overlay as a Browser Source (720×1280 or 1080×1920).
- **Lightweight server only** (Castle Clash and overlays, without built-in streaming or Minecraft): Render's free plan via `render.yaml`, or `npm install && ADMIN_KEY=secret TIKTOK_USERNAME=you npm start`.

## Also included
- **Dashboard** (`/`): live feed, stats, test buttons (no need to be live), the Actions editor, the Game tab and settings. It works on your phone.
- **Screen alerts, sounds and text-to-speech** for gifts, follows, shares, likes and chat commands.
- **Overlays:** `/overlay/alerts`, `/overlay/chat`, `/overlay/goal` and `/overlay/top`.
- **Auto-connect:** the server joins your LIVE as soon as it starts and reconnects if the connection drops.

## Environment variables

| Variable | Purpose |
|---|---|
| `TIKTOK_USERNAME` | Your TikTok username (no `@`) |
| `ADMIN_KEY` | Dashboard password. **Always set this on a public server.** |
| `GAME_PATH` / `GAME_CMD` | What the stream shows (see above) |
| `COMPOSE_PROFILES=minecraft`, `MINECRAFT_EULA`, `MC_HOST`, `RCON_PASSWORD` | Minecraft on/off, EULA acceptance, connection |
| `MC_BOT_NAME` (`Steve`), `MC_FIRST_PERSON` (1), `MC_LEVEL_UP_SECONDS` (150), `MC_RESPAWN_KIT`, `MC_ARENA_RADIUS` (24), `MC_IDLE_MOB_SECONDS` (25, 0 = off), `MINECRAFT_MEMORY` (4G) | Minecraft tuning |
| `STREAM_URL`, `STREAM_KEY` | Optional: the stream key can be set in the dashboard instead |
| `STREAM_BITRATE`, `STREAM_FPS`, `STREAM_WIDTH`, `STREAM_HEIGHT` | Stream quality (default 2500k, 30 fps, 720×1280) |
| `SIGN_API_KEY` | Optional free key from [eulerstream.com](https://www.eulerstream.com), for higher rate limits on the TikTok connection |

TikTok has no official API for LIVE events. This tool uses the community library [`tiktok-live-connector`](https://github.com/zerodytrash/TikTok-Live-Connector). If TikTok changes something, update with `bash setup-vm.sh`, which pulls the latest code and rebuilds.
