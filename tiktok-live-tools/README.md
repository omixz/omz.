# TikTok LIVE Tools

Interactive TikTok LIVE games where **viewers' likes and gifts control the action**. They run **24/7 on a free cloud server**, with no gaming PC and nothing for you to touch.

| Game | What it is |
|---|---|
| ⛏️ **Minecraft: hero vs viewers** (`/minecraft`) | A **real Minecraft server** with a bot player fighting to survive. Gifts **hurt** it (zombies, creepers, TNT, boss raids, all named after the viewer who sent them) or **help** it (iron and diamond gear, golden apples, healing). The stream shows a live 3D camera, the survival timer, deaths and kills, who just did what, and what each gift does. |
| 🏰 **Castle Clash** (`/game`) | A two-team battle that runs in a browser. Viewers comment 1 or 2 to pick a team, likes send soldiers, gifts send knights, giants, dragons and meteors. |
| 🎮 **Any other game** | Actions can **press keys** in any game running on the stream server, and `GAME_CMD` streams any Linux game instead of a web page. |

---

## ⛏️ Minecraft: how it works

```
TikTok gifts ─▶ LIVE Tools ─▶ RCON commands ─▶ real Minecraft server (Paper 1.21.4, private)
                                                     ▲
             bot player "LiveHero" ──────────────────┘  fights mobs, equips gifted gear, eats, respawns
             3D camera (prismarine-viewer) ─▶ /minecraft page ─▶ ffmpeg ─▶ TikTok
```

**Default actions.** They switch on by themselves the first time the hero joins, and you can edit them in the dashboard's **Actions** tab.

| Viewer sends | In Minecraft |
|---|---|
| Gift 1–4 🪙 (Rose…) | 🧟 a zombie named after the viewer, one per gift in a combo |
| Gift 5–9 🪙 | 💀 a skeleton |
| Gift 10–29 🪙 | 🛡️ full iron gear and food *(help)* |
| Gift 30–98 🪙 | 💥 a squad of 3 creepers |
| Gift 99–198 🪙 | 💎 full diamond gear and golden apples *(help)* |
| Gift 199–499 🪙 | 🧨 TNT rain |
| Gift 500+ 🪙 | 👹 boss raid: lightning, a ravager, vindicators and a witch |
| Follow | 🍎 golden apple *(help)* |
| Share | ❤️‍🩹 instant heal *(help)* |
| Every 100 likes | ✨ regeneration *(help)* |
| Chat `!zombie` | 🧟 a zombie (15-second cooldown) |

**Built to run for days.** Only viewers spawn mobs, and a lone zombie wanders in when chat is quiet so the stream never looks frozen. Creepers don't break blocks, and TNT holes are repaired every minute. Dropped items are cleared, and a world border keeps everything on camera. Gifted gear is kept after death. The bot, camera, server and stream all restart themselves.

**Write your own actions.** Any action can run Minecraft commands, one per line. Placeholders:
- `{bot}`: the hero
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
1. Create an **Ubuntu** VM on Oracle (shape **VM.Standard.A1.Flex**). In its *Virtual Cloud Network → Security List*, add ingress rules for **TCP 3000** (dashboard) and **TCP 3007** (Minecraft camera preview).
2. SSH into the VM and run one command. It asks for your TikTok username and the Minecraft EULA, generates the passwords, then builds and starts everything:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/omixz/omz./main/tiktok-live-tools/setup-vm.sh | bash
   ```
   (If the repo is private, clone it first with a GitHub token, then run `bash omz/tiktok-live-tools/setup-vm.sh`.)
3. Open the dashboard address it prints on your phone, enter the password it prints, and go to **Settings → Cloud streaming** to paste the Server URL and Stream key.

Run the same command again any time to update.

### What still needs you (TikTok's rules, not this tool's)
- **Starting the LIVE.** TikTok doesn't let any tool go live for you. In LIVE Producer, press **Go LIVE**; the game feed is already arriving. While you aren't live, TikTok ignores it.
- **A new stream key.** If TikTok gives you a new key, paste it in the dashboard. The server switches within about 5 seconds.
- **TikTok's LIVE guidelines.** TikTok can limit LIVEs it sees as unattended or repetitive. Hosting now and then and replying to chat helps.

### Switching games
Set `GAME_PATH` in `tiktok-live-tools/.env`, then run `sudo docker compose up -d`:
- `GAME_PATH=/minecraft`: Minecraft hero vs viewers (default)
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
| `MC_BOT_NAME` (`LiveHero`), `MC_ARENA_RADIUS` (24), `MC_IDLE_MOB_SECONDS` (25, 0 = off), `MINECRAFT_MEMORY` (4G) | Minecraft tuning |
| `STREAM_URL`, `STREAM_KEY` | Optional: the stream key can be set in the dashboard instead |
| `STREAM_BITRATE`, `STREAM_FPS`, `STREAM_WIDTH`, `STREAM_HEIGHT` | Stream quality (default 2500k, 30 fps, 720×1280) |
| `SIGN_API_KEY` | Optional free key from [eulerstream.com](https://www.eulerstream.com), for higher rate limits on the TikTok connection |

TikTok has no official API for LIVE events. This tool uses the community library [`tiktok-live-connector`](https://github.com/zerodytrash/TikTok-Live-Connector). If TikTok changes something, update with `bash setup-vm.sh`, which pulls the latest code and rebuilds.
