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

## 🧪 Free test drive (GitHub Codespaces, no server needed)

Try the whole thing in your browser for free: a real Minecraft server, Steve, the hub and the stream page.

1. On GitHub, open this repo → **Code** → **Codespaces** → **Create codespace on main**. To be asked for the Minecraft EULA and your TikTok username, use **⋯ → New with options** instead.
2. Wait for it to build (first time ~5–10 minutes). It starts everything by itself.
3. Open the **Ports** tab → port **3000** ("Steve LIVE Hub"). It's private to your GitHub account. Use the test buttons, and open `/minecraft` to watch Steve.
   Minecraft starts only once you accept [its EULA](https://aka.ms/MinecraftEULA): enter `TRUE` for MINECRAFT_EULA when creating the codespace, or run `bash tiktok-live-tools/codespace-start.sh --accept-eula` in its terminal.

GitHub accounts include 120 free core-hours of Codespaces a month, about 60 hours on this 2-core machine. Stop the codespace when you're done. **This is for testing only.** GitHub's terms don't allow Codespaces to host a public ("production") stream, so for going live, use a server (below).

## 🤖 Going live 24/7: a server that sets itself up

Rent any small Ubuntu server and paste [`cloud-init.yaml`](cloud-init.yaml) into its **Cloud config / User data** box while creating it. The server then installs and starts everything by itself: no terminal, no commands.

### What you need
1. **A TikTok stream key.** Open [TikTok LIVE Producer](https://livecenter.tiktok.com/producer). If your account has it, you'll see a **Server URL** and a **Stream key**. TikTok decides which accounts get this.
2. **A server with at least 4 vCPU and 8 GB RAM**, Ubuntu 22.04 or 24.04, from any provider whose create page has a "Cloud config" or "User data" box. For example:
   - **Hetzner** CAX21 (4 ARM vCPU, 8 GB, about €11 a month) or a 4 vCPU / 8 GB x86 plan
   - **DigitalOcean**, **Vultr** or **Linode**: a 4 vCPU / 8 GB plan
   - **Oracle Cloud Always Free**: VM.Standard.A1.Flex with 4 OCPU and 24 GB, free but with a fiddly sign-up. Open TCP 80, 443 and 3000 in its Security List.

### Steps
1. Copy [`cloud-init.yaml`](cloud-init.yaml) and change its 3 lines:
   - your TikTok username
   - a hub password (letters and numbers only)
   - `ACCEPT_MINECRAFT_EULA=yes`, once you've read [the EULA](https://aka.ms/MinecraftEULA)
2. Create the server and paste the whole file into **Cloud config / User data**.
3. After about 10 minutes, open `https://<server-ip-with-dashes>.sslip.io` (server IP `157.90.12.34` gives `https://157-90-12-34.sslip.io`). That's your **hub**, with a free https certificate and no domain needed. Log in with your hub password, then paste the Server URL and Stream key in **Setup**.

If the server has no Cloud config box, SSH in and run `curl -fsSL https://raw.githubusercontent.com/omixz/omz./main/tiktok-live-tools/setup-vm.sh | bash`. It asks the same questions. Run it again any time to update.

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
