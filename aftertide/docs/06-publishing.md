# 6. Play, Publish & Grow, for US$0

Everything below is free. Roblox hosts the servers, scales them automatically, and takes
its share only when players spend Robux.

## 6.1 What you need

- A Roblox account. To cash out later through DevEx you must be 13+, ID-verified and have
  a verified email.
- **Roblox Studio** (Windows or Mac, free): <https://create.roblox.com>
- This repository (GitHub → **Code → Download ZIP**, or `git clone`).
- *Optional, for coding:* VS Code + the free **Rojo** plugin, to edit `src/` and live-sync
  into Studio. Not required to play or publish.

## 6.2 Play it in Studio (5 minutes)

1. In Studio: **File → Open from File…** → `aftertide/build/Aftertide.rbxlx`.
2. In **Explorer → Lighting**, check that the **Technology** property is **Future**. If it isn't,
   set it.
3. **Home → Game Settings → Avatar → Avatar Type: R15.** The crew pose code needs R15.
   (Publish first if Game Settings asks you to; see 6.3.)
4. Press **Play** (F5). Choose a crew member and a starting perk, walk to the **tide chart**
   on the ferry deck, and hold **E** to begin a crossing.
5. **Test co-op:** **Test** tab → *Clients and Servers* → choose **2 players** (up to 4) →
   **Start**. Several windows open, one per player.

**Controls:** WASD move · Shift sprint · C or Ctrl crouch · 1 long gun · 2 sidearm ·
3 holster · right mouse aim · left mouse fire · R reload (Second Wind when downed) ·
F Quieting / shove · G throw · Z next throwable · Q ability · H Field Dressing · T torch ·
X swap shoulder · Tab satchel and crafting · B resupply · P settings · E interact/search.
Gamepad: L2/R2 aim and fire, X reload or Quiet (contextual), R1/L1 throw/next throwable,
D-pad right cycles weapons. Touch buttons appear automatically.

**How a crossing works:** hold E at the tide chart to start, prepare at the workbench,
then pick a route. Each stop is Salvage (find crates, reach the flare), Lantern Watch
(defend the lantern through waves) or Drift (survive being hunted, then extract). Search
drawers, lockers and crates for parts and ammo, craft in the satchel (Tab), and stay
quiet: gunshots bring every Hushed nearby. After 3 stops comes the finale, The
Breakwater. Scrip from every cleared stop repairs the Meridian permanently.

**Messages you can ignore in Output during local testing:**
`[PlayerData] DataStores unavailable: using memory only`. This appears until the
experience is published and Studio API access is on (6.3).

## 6.3 Publish the experience

1. **File → Publish to Roblox As… → Create new experience.** Name: **AFTERTIDE**. Pick
   the creator (you, or a Roblox group if you'd like co-owners later). Genre: Survival.
2. **Home → Game Settings:**
   - **Security → Enable Studio Access to API Services: ON.** Saving then works in Studio
     tests.
   - **Avatar → Avatar Type: R15.**
   - **Permissions → Private** while you test.
3. **Server size (how many players per crossing):** Creator Hub
   (<https://create.roblox.com/dashboard/creations>) → AFTERTIDE → **Places** → the place
   → **Configure**/**Settings** → **Server size = 4**. This must match
   `Game.MaxPartySize` in `src/shared/Config/Game.luau`. Want bigger groups? Raise both. Duo
   is what difficulty is tuned around, and enemies scale up automatically for larger groups.
4. Every time you change something: **File → Publish to Roblox** (Alt+P).

## 6.4 Maturity & compliance questionnaire (required)

Creator Hub → AFTERTIDE → **Audience → Maturity & Compliance** → answer honestly:
fictional weapons used against non-human creatures, no blood or gore (they burst into
salt), fear and horror themes present. Expect the **Moderate** label (the target we chose). Re-answer it
whenever the content changes. Wrong answers can get the experience moderated.

## 6.5 Turn on the run-aid products

1. Creator Hub → AFTERTIDE → **Monetization → Developer Products → Create**. Create
   three:
   | Name | Price (Robux) | Description |
   |---|---|---|
   | Second Wind | 49 | Get back up once when you're downed. Max one per crossing. |
   | Second Wind x3 | 129 | Three Second Wind tokens. Same once-per-crossing limit. |
   | Resupply Satchel | 29 | +4 Salt Shot, +1 Bottle, +1 Bandage. Once per crossing. |
2. Copy each **Product ID** into `src/shared/Config/Commerce.luau` (`productId = ...`).
   - Without Rojo: in Studio, edit **ReplicatedStorage → Shared → Config → Commerce** directly.
   - With the repo: edit the file, run `python3 aftertide/tools/build_place.py`, and reopen
     the rebuilt place (or use Rojo).
3. Test in Studio. Purchases there are **test purchases**: no Robux is charged.
4. *Optional:* **Monetization → Private Servers → Enable.** Start at **0 Robux** (free)
   to help friend groups and creators adopt the game. Charge 100 R$/month once there's
   demand.
5. Don't want paid run aids? Set `RunAidsEnabled = false` in `Config/Game.luau`.

## 6.6 The $0 asset pipeline (for Stages 2 to 5)

| Need | Free option | Licence notes (log every asset in the register, doc 4 §4.4) |
|---|---|---|
| 3D models | **Blender** (free), your own models | You own them |
| Textures | **ambientCG**, **Poly Haven**: CC0 | CC0 allows commercial use. Save the page link. |
| Extra models | Poly Haven / Kenney packs marked **CC0** | Check every page says CC0 |
| Character rigs | Blender + Roblox **Avatar Setup / Rig Builder** | Your own work |
| Animation | Roblox **Animation Editor** + **Animation Capture** (record yourself on a webcam or video) | Your own performance, so you own it |
| Sound effects | Your own phone Foley (doors, footsteps on gravel, glass), **freesound.org filtered to CC0** | Avoid CC-BY-NC (non-commercial). CC-BY needs a credit. |
| Music | Roblox-licensed tracks in the Creator Store audio library | **In-Roblox use only**: not for trailers or TikTok |
| Fonts | Roblox's built-in fonts (Oswald, Merriweather used here) | Included with Roblox |
| UI icons | Draw them yourself (Figma or Photopea free tiers) | You own them |

**Never** use Creator Store *free models* in the released game: they can hide malicious
scripts and stolen assets (doc 4 §4.4).

## 6.7 Before you set it public

- [ ] 3 or more friends play it privately in a 2 to 4 player server; fix what they hit.
- [ ] Icon (512×512) and 3 or more thumbnails (1920×1080) **taken from the real game**.
      No misleading art.
- [ ] Description (draft below). No mention of other games or brands.
- [ ] Maturity questionnaire done (6.4).
- [ ] Product IDs set and test purchases work (6.5).
- [ ] **Permissions → Public.**

**Description draft:**

> The sea took the noise. Don't give it yours.
> Eleven years after the Pall rolled in, the Marrow Coast belongs to the Hushed: silent
> figures drawn to light and sound. Leave the beached ferry *Meridian*, scavenge the fog,
> and get your crew home.
> • Stealth-first survival for 1 to 4 players • 4 crew members with their own loadouts and
> perks • Every crossing changes: fog, storms, echoes • Crouch, distract, and Quiet them
> from behind
> Early access: Cannery Row is open. More of the coast is coming.

## 6.8 Free growth plan

1. **Short-form video:** 15 to 30 second clips of tense moments (a Hushed passing just
   behind someone in the reeds). Your `tiktok-live-tools/` setup in this repo can stream
   play sessions too.
2. **Roblox DevForum → Creations Feedback:** post early and ask specific questions.
3. **A Discord server and a Roblox group:** patch notes, playtest calls, a bug-report
   channel.
4. **Update rhythm:** ship something every 2 weeks (a map, a modifier, an enemy). Roblox
   discovery rewards experiences that retain players and keep changing.
5. **Watch the numbers** (Creator Hub → Analytics): **D1 retention** (target above 30%),
   **D7** (above 10%), **average session** (above 20 min), qualified play-through.
   Improve those before you spend anything on ads.

## 6.9 Troubleshooting

| Symptom | Fix |
|---|---|
| Characters look R6 or the crouch pose is broken | Game Settings → Avatar → **R15**, then publish |
| Nothing saves | Publish, then Game Settings → Security → **Studio Access to API Services ON** |
| "NOT SET UP" on shop buttons | Product IDs are still 0 in `Config/Commerce.luau` (6.5) |
| Everything very dark or flat | Lighting → Technology = **Future**. Check the graphics quality setting in the Roblox menu. |
| Players can't join each other | Server size too small (6.3 step 3) |
| Gunshots are silent | Add gun sounds in `Config/Sounds.luau` (doc 7). Empty IDs mean no sound. |
| Characters still look like mannequins | Add realistic rigs to ServerStorage → Rigs (doc 7 §7.2) |
| A red error in Output | Copy the full error text (it names the script and line) and send it to me |
