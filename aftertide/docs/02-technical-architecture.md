# 2. Technical Architecture

## 2.1 Toolchain (decided)

| Concern | Choice | Reason |
|---|---|---|
| Source control | Git (this repo) + **Rojo** syncing files into Studio | Real version control, code review and branches. Studio-only scripts can't be diffed. |
| Packages | **Wally** | Pinned third-party Luau libraries |
| Language mode | `--!strict` Luau + **luau-lsp** | Type errors caught before playtest |
| Lint / format | **Selene** + **StyLua** | Consistent code, with common bugs caught in CI |
| Tests | **Jest-Lua** for pure logic (inventory, crafting, run generation, data migrations) | Logic that handles money and saves gets tests |
| Save data | **ProfileStore** (MIT, by loleris) | Session locking prevents item duplication across servers |
| Assets | Blender → FBX → Studio, with every asset ID logged in the asset register (doc 4) | Provenance for IP and licensing |

All third-party packages must use permissive licences (MIT, Apache 2.0, BSD) and be
recorded in the asset register.

## 2.2 Universe layout (places)

```
AFTERTIDE (Experience / Universe)
├── Harbour   (start place)  – social lobby, wardrobe, Purser's shop, party up, tutorial
│                              Public servers, up to 20 players. Private servers enabled.
└── Crossing  (run place)    – the Meridian hideout + encounter maps, one party per server
                               Reserved servers via TeleportService, 1–2 players (up to 4 later)
```

**Why the hideout lives in the Crossing place and not the lobby:** going back to the
hideout between encounters must take a couple of seconds, not a 10 to 20 second
teleport. Inside the Crossing place, the *Meridian* is a permanent area and encounter
maps are loaded from `ServerStorage` and placed far away. The player fades out, the map
loads, and the player fades in.

**Party handoff:** the Harbour server writes the party record (UserIds, chosen
characters, difficulty) to **MemoryStoreService** under a key, reserves a server and
teleports the party along with that key. The Crossing server reads and validates the
record from MemoryStore. **Teleport data passed through the client is never trusted**,
because it can be tampered with.

## 2.3 Code layout (Rojo project)

```
aftertide/
├── default.project.json
├── wally.toml
└── src/
    ├── shared/                      → ReplicatedStorage.Shared
    │   ├── Config/                  (tuning tables: enemies, items, recipes, encounters, prices)
    │   ├── Types.luau               (shared type definitions)
    │   ├── Net/                     (typed remote definitions + client/server wrappers)
    │   ├── Util/                    (Signal, Janitor/Trove, Spring, Maid, RNG)
    │   └── Catalog/                 (cosmetic & product catalogue — single source of truth)
    ├── server/                      → ServerScriptService.Server
    │   ├── Main.server.luau         (boots services in dependency order)
    │   └── Services/
    │       ├── PlayerDataService    (ProfileStore, schema versions, migrations)
    │       ├── PartyService         (MemoryStore handoff, reserved servers)
    │       ├── CrossingDirector     (run state machine: Ferry → Chart → Encounter → Ferry …)
    │       ├── EncounterService     (load/unload maps, objectives, win/lose)
    │       ├── PacingDirector       (tension model, spawn budget, Pall Level)
    │       ├── EnemyService         (spawn, LOD, per-enemy brains)
    │       ├── PerceptionService    (sight/hearing queries, noise events)
    │       ├── CombatService        (validated melee/takedown/stun/throwables)
    │       ├── InventoryService     (satchel, pickups, server-owned truth)
    │       ├── CraftingService
    │       ├── ProgressionService   (salt, skills, keepsakes, mastery, logbook)
    │       ├── CosmeticService      (equipped cosmetics → applied to rigs)
    │       ├── CommerceService      (ProcessReceipt, game passes, subscriptions)
    │       ├── CharacterService     (spawns custom rigs, disables default avatars)
    │       └── AntiCheatService     (movement sanity, remote rate limits, flags)
    └── client/                      → StarterPlayer.StarterPlayerScripts.Client
        ├── Main.client.luau
        └── Controllers/
            ├── CameraController     (over-the-shoulder rig)
            ├── MovementController   (stance, speed states, input → ControllerManager)
            ├── AnimationController  (locomotion blending, IK, upper-body layers)
            ├── InteractionController(context prompts, hold-to-interact)
            ├── StealthHUDController (noise ring, detection indicators)
            ├── AudioController      (Audio API graph, music state machine, reverb zones)
            ├── UIController         (satchel, tide chart, shop — all custom UI)
            └── PostFXController     (colour grade, DoF, damage/breathing vignette)
```

Each service and controller exposes `init()` and `start()`. `Main` requires them all,
calls every `init()` (wiring only, no yielding), then every `start()`. There are no
circular requires. Services talk to each other through methods and signals, and talk to
clients only through `Shared/Net`.

## 2.4 Server authority & security model

**Rule: the client sends *intent*, the server decides *outcome*.**

| System | Client may | Server decides |
|---|---|---|
| Movement | Simulate its own character (Roblox physics ownership) | Sanity checks: max speed per stance, teleport detection, noclip raycasts. Rubber-band or flag. |
| Melee / Quieting | Request "takedown on enemy X" | Range, facing angle, enemy state (unaware?), cooldown, line of sight |
| Throwables | Request a throw with an aim direction | Simulates the projectile, the impact and the noise event |
| Pickups / crafting | Request "pick up item #id" / "craft recipe R" | Distance, existence, inventory space, ingredients |
| Currency / unlocks | Nothing | Only server code changes salt, scrip, mastery or owned items |
| Purchases | Prompt a purchase | `ProcessReceipt` grants it, idempotently, by receipt ID stored in the profile |

Every remote is wrapped. The wrapper type-checks its arguments, rate-limits per player
per remote, and drops or flags anything malformed. Numbers are checked for NaN, infinity
and range.

**Honest limitation:** Roblox gives clients physics ownership of their own characters,
so movement is never fully server-authoritative. We catch speed and teleport cheating
after the fact. In a co-op PvE game this risk is acceptable. We will never add
competitive leaderboards whose rewards rely on trusting client movement.

## 2.5 Characters, camera & movement

### Custom characters

- `StarterPlayer.CharacterAutoLoads` is off. `CharacterService` clones the chosen
  crew rig from `ServerStorage/Rigs` and assigns it to `player.Character`.
  `LoadCharacterAppearance` is off. The player's Roblox avatar is never shown in a run.
  In the Harbour lobby it can optionally appear, as Roblox players like to see it.
- Rig: a custom **skinned mesh** with an R15-compatible bone hierarchy, so the
  Animation Editor, `IKControl` and Roblox animation tooling all work. **FACS** face
  rig for expressions. LODs: hero (about 10k tris), mid, and far (about 2k).
- Physics: the `Humanoid` is kept for the camera, the `Animator` and ecosystem
  compatibility, and locomotion is driven by Roblox's physics character controller
  (`ControllerManager` + `GroundController` / `SwimController`). This gives
  acceleration curves, slope handling and momentum, so movement feels weighty instead
  of the default instant-stop.

### Camera (`CameraController`)

- `Camera.CameraType = Scriptable`, driven every `RenderStepped` frame.
- A pivot above the character's shoulder; a damped **spring** on position and a
  separate spring on rotation (critically damped, with a tunable frequency).
- **Collision:** a `workspace:Spherecast` from pivot to desired camera position, which
  pulls the camera in smoothly and eases it back out more slowly.
- States, each with its own offset, FOV and spring settings: *Explore*, *Sprint* (FOV
  +6, slight lag), *Crouch* (lower, closer), *Aim* (tight shoulder, FOV −15),
  *Takedown* (scripted cinematic framing), *Ferry* (slower, wider).
- Shoulder swap on input, with automatic swap when the near wall would block the
  camera.
- Subtle procedural motion: breathing sway, footstep impulses, landing dips. All of it
  is scaled by an accessibility setting, with a "reduce camera motion" toggle.
- Gamepad, mouse and touch handled separately. On mobile: a right-side drag camera,
  auto-aim assist for throwables, and contextual buttons.

### Movement (`MovementController`)

Stances: **stand / crouch / prone-lite (low crawl)**. Speed states: **walk / jog /
sprint**. Each combination has a speed, an acceleration and a **noise radius**, all in
`Config/Movement`. Prone-lite is a crouch-crawl for tall grass and vents, not a full
prone system; full prone animation with terrain alignment costs too much for its value.
Extras: vaulting low obstacles (raycast check plus an animation-driven move), squeezing
through gaps (scripted traversal), wading (slower, louder unless you're Mara).

## 2.6 Animation system (`AnimationController`)

Roblox has no visual blend tree, so we build one in code:

- **Locomotion blend:** idle/walk/jog/sprint tracks per stance all play at once, with
  weights set every frame from velocity using `AnimationTrack:AdjustWeight` and
  `AdjustSpeed`, so foot cadence matches ground speed.
- **Directional strafing** while aiming, from 8 directional clips blended by the angle
  between velocity and facing.
- **Layers:** a full-body base layer, an upper-body action layer (throw, light toggle,
  bandage) using priority and partial-body animations, and an additive breathing and
  injury layer.
- **IK:** `IKControl` for foot planting on slopes and stairs, head look-at toward
  noises and points of interest, and hand placement on ledges and doors.
- **Transitions:** start, stop and turn-in-place clips triggered by velocity changes.
  These matter a lot for avoiding the "Roblox slide" feel.
- **Sync points:** takedowns use paired animations. The enemy is snapped to an
  anchored offset, then both clips play together. The server validates the takedown,
  and the client plays it immediately so it feels responsive.

**Animation sources:** our own motion capture (inertial suit or video-based mocap
services, cleaned up in Blender), or bought packs with a **game-use commercial licence
on file**. No ripped animations, ever.

## 2.7 Enemy AI

### Structure

- **EnemyService** owns all enemies. Each enemy is a lightweight rig (custom skinned
  mesh with an `AnimationController`, **no Humanoid**) moved by the server by setting
  CFrames along a path. This costs much less than Humanoids, gives exact control and
  makes it easy to support 20 or more enemies.
- **Slice 0 note:** the prototype Drifters use a simple `Humanoid` for movement (fine for
  13 or fewer enemies). The CFrame-driven, no-Humanoid mover replaces it in Stage 6 once the
  enemy count goes up.
- **Brain:** a hierarchical state machine per enemy:
  `Dormant → Idle/Patrol → Suspicious → Investigating → Alerted → Pursuing → Searching → (back to Patrol)`
  plus `Stunned`, `Pinned`, `Dispersing`.
- **Navigation:** `PathfindingService` with **PathfindingModifiers** for fog
  corridors, water and no-go areas. Paths are cached and recomputed only when the
  target moves more than N studs. Patrol routes are authored as waypoint chains in each
  map.
- **Tick budget:** brains are updated in staggered batches (for example a third of the
  enemies each Heartbeat). Enemies more than about 150 studs from every player go
  `Dormant` (no brain, no animation). A global AI budget of about 2 ms per frame is
  checked with the MicroProfiler.

### Perception (`PerceptionService`)

- **Sight:** a cone (angle and range per enemy type, scaled by fog density and light).
  Checks: in range → in cone → **raycast to several bone points** (head, chest, feet)
  → visibility score. The score depends on the player's stance, movement, whether they
  are lit (holding a light, or standing inside a light volume) and cover (tall grass,
  smoke). The score fills a **suspicion meter** per enemy per player.
- **Hearing:** all gameplay sounds are **noise events** `{position, loudness, type}`
  raised on the server (footsteps from speed state and surface, thrown bottles,
  combat, doors). Loudness falls off with distance, and occlusion is a single raycast
  that halves loudness through walls. The *Squall* modifier scales footstep loudness
  and *Echoing* scales the falloff distance.
- **Communication:** the Bellwether hum is a large noise event that sets every Hushed
  in range to `Investigating` at its position.
- **Readability:** detection must always be readable. Each enemy shows a directional
  indicator that fills (white for suspicious, amber for searching, red for alerted)
  plus audio stingers. Being spotted unfairly loses players faster than anything else.

### Pacing (`PacingDirector`)

A pacing director in the style of *Left 4 Dead*. It tracks each player's **intensity**
(recent damage, how many enemies are alerted, near misses), ramps the spawn budget up
during build-up, stops spawns at the peak, and holds a relaxed phase afterwards. The
Pall Level scales the budget and unlocks more dangerous enemy types. Encounter configs
specify the spawn points and budget curves; the director picks from them.

## 2.8 Encounters & procedural selection

- Each **encounter map** is a `Model` in `ServerStorage/Maps`, with tagged
  (`CollectionService`) spawn points, loot containers, patrol chains, objectives and
  exits. Maps are hand-built. Procedural generation is limited to *which* map, *which*
  objective variant, *which* modifiers and *where* loot, patrols and spawns go. Fully
  procedural levels would look bad on Roblox and wouldn't be premium.
- **Run generation:** a seeded RNG (the seed is stored, so runs can be replayed and
  debugged) builds the tide chart from weighted tables with constraints: no repeated
  map in a run, at least one *Salvage* per Reach, *Drift* never twice in a row, and so
  on.
- Map pool at launch: about 8 maps × 2 to 3 layout variants (gates open or shut, flood
  levels) × objective types × modifiers. That's enough variety for about 50 hours
  before players start recognising repeats; seasons add maps.

## 2.9 Inventory, crafting, items

- The **satchel** has fixed slots: 4 throwables, 3 consumables, 1 tool, plus a parts
  pouch with a cap per part. It's deliberately small to force choices. **Satchel size
  is never sold.**
- All recipes and items live in `Config/Items` and `Config/Recipes`. One data table
  drives the UI, the server and balancing.
- Crafting happens in real time with an interruptible animation (1.5 to 3 s). In the
  field you can craft only basic items; full crafting needs the ferry workshop.

## 2.10 Save data

ProfileStore profile, one per player, **schema-versioned**:

```lua
{
  version = 1,
  crew = { [characterId] = { mastery = 0, xp = 0, cabin = {...}, equipped = {...} } },
  unlocks = { characters = {...}, keepsakesSeen = {...}, logbook = {...} },
  meridian = { repairs = {...} },
  cosmetics = { owned = {...} },          -- granted by CommerceService or earned
  tidePass = { [seasonId] = { premium = false, tier = 0, xp = 0 } },
  stats = { runs = 0, clears = {...}, bestTier = 0 },
  receipts = { [purchaseId] = true },     -- idempotent purchase log (pruned to last N)
  settings = {...},
  activeRun = nil,                        -- optional checkpoint at the ferry (resume)
}
```

- **Migrations** are a function per version (`v1 → v2`), covered by tests.
- An **in-progress run** is checkpointed only at the ferry phase. If you disconnect,
  you can resume from the last ferry stop. This is important for mobile players.
- Global data (seasons, featured shop, events) lives in **DataStore** and
  **MemoryStore** and is read through a cached config service, so content can change
  without republishing the place.
- **Analytics:** Roblox `AnalyticsService` custom and economy events (funnels: tutorial
  → first run → first clear; salt sinks and sources; shop impressions → purchases).

## 2.11 Multiplayer

- **Launch:** solo to **4-player** co-op in the Crossing place (duo is the tuned baseline).
  Perception and pacing are per player, and enemy count scales with party size
  (`Game.BaseEnemies + EnemiesPerExtraPlayer`, capped at `MaxEnemies`). The party cap is
  `Game.MaxPartySize`, and the server size is set to match in the Creator Hub.
- **Hosting costs nothing:** Roblox runs and adds servers automatically. The Harbour
  lobby can hold 30 or more players per server; each Crossing is its own server.
- A downed player can be revived by a partner. If they bleed out, they spectate until
  the next ferry phase. Nobody waits long.
- Server CPU must be profiled at 4 players + 13 enemies before launch (MicroProfiler, Developer Console → Server Stats).

## 2.12 Audio

Roblox's **Audio API** (`AudioPlayer`, `AudioEmitter`, `AudioListener`, effect
instances connected by wires) gives us per-zone reverb (ferry hull, cannery, open flats),
dynamic low-pass filtering when you're behind walls or in thick fog, and a
**layered music system**: stems for *explore / tension / detected / chase / release*,
crossfaded by the stealth state of the nearest enemies. Footstep sounds come from
material and stance tables. All audio is original or commercially licensed (doc 4).

## 2.13 Lighting & rendering

- `Lighting.Technology = Future`, with `Atmosphere` for the Pall (density
  tuned per encounter and modifier), `ColorCorrection` for the grade, `Bloom`,
  `DepthOfField` (ferry and cinematics only) and `SunRays` (Moonbreak).
- **Fog as a design tool:** layered fog cards (particle emitters with large, soft,
  slow particles) near the ground, plus Atmosphere density, give volumetric-looking fog
  at a fraction of the cost of real volumetrics. Roblox doesn't offer real volumetrics.
- `SurfaceAppearance` PBR on hero assets and **shared texture atlases** for
  environment kits, so draw calls and memory stay down.
- Light budget: a few shadow-casting lights near the player (lanterns, the player's
  torch), and the rest non-shadowed. Lights are toggled by distance with LOD.

## 2.14 Performance budgets

| Budget | Desktop (mid) | Mobile (mid, e.g. 4 GB phone) |
|---|---|---|
| Frame rate | 60 fps | 30 fps stable |
| Client memory | < 1.5 GB | < 700 MB (Roblox kills the app above device limits) |
| Unique meshes per map | ~250 | same (mobile uses lower LODs) |
| Active enemies | 20 | 20 (animations throttled at a distance) |
| Server Heartbeat | < 8 ms (AI ≤ 2 ms) | — |
| Network | < 50 KB/s per client | same |

Practices: `StreamingEnabled` with tuned target and min radii; models set to
`Atomic` / `Persistent` where they need it; `CollisionFidelity = Box` on props;
`CanQuery` and `CanTouch` turned off where unused; no `while true` loops polling state;
event-driven UI; `task.defer` and `task.delay` instead of `spawn`/`wait`.
Quality presets react to the player's graphics level (fewer fog cards, fewer shadowed
lights, lower LOD distances).

## 2.15 Roblox engine limits (the honest list)

| Limit | Impact | Our mitigation |
|---|---|---|
| No custom shaders or post-process shaders | We can't write our own fog, SSAO or outlines | Atmosphere, ColorCorrection, fog cards, baked detail in textures |
| No real volumetric lighting or GI | Lighting looks flatter than console | Future lighting, careful practical lights, the art direction leans on darkness |
| Mostly mobile players | Memory, CPU and thermal limits | Fog-limited view distance, aggressive LOD, quality presets |
| Client physics ownership | Movement cheats are possible | Server sanity checks; PvE-only design |
| No native blend trees or animation state machines | More animation code to write | Custom blend layer (§2.6) |
| Font set limited to Roblox's library | Branding typography is constrained | Title and logo as images; UI uses the closest built-in families |
| Audio upload limits and moderation | Long music files need moderation time | Stems, upload early, keep copies of licence proof |
| Teleports take 5 to 20 s | Hub ↔ run transitions are slow | Hideout lives inside the run place (§2.2) |
| Content maturity labels limit the audience | A dark tone pushes us up the rating scale | Non-graphic design, aimed at the **Moderate** label (doc 4 §4.5) |
| No offline play; servers shut down on update | Runs can be lost | Ferry checkpoints, soft-shutdown script that migrates players on update |
