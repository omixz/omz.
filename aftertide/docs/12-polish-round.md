# 12. Polish round: Meridian, look, animations, console, Lucky Spin

Everything below was built, published to the place and checked in the real engine
(renders in this folder come from engine data: `tools/render_scene.py`, `render_engine_result.py`).

## The Meridian and how to start
- Rebuilt as a bright harbour ferry: white/teal/red hull, teak deck, funnel with smoke, bunting,
  life rings, planters, a pier with lamps, an island and lighthouse across the bay.
- Every station has a floating name card (SET SAIL, QUARTERMASTER, SHOP, WORKBENCH, WARDROBE,
  QUESTS, PROJECTS, CREW CABINS, LUCKY SPIN). Players spawn facing the chart table.
- **SET SAIL** is the one obvious start: a gold light column over the chart table, a SET SAIL
  button on screen while on deck, and for new players a 3-step *Captain's Orders* card plus a
  gold guide line from your feet to the table. It disappears after your first crossing.
- Layout check: 0 overlaps with no projects built and with all of them (`docs/engine-meridian.png`).

## Look
- New blue-sky skyboxes (golden sunset on Larkspur Street), sunny lighting, positive saturation.
- Houses are generated, not copied: 6 roof styles (gable, side gable, cross gable, flat, saltbox,
  cabin), painted upper storeys, verandas, door positions, pastel paint + trim + shutters, brick or
  stucco, flower boxes, chimneys, picket fences, 3 interior layouts (`docs/engine-houses.png`).
- Crew re-sculpted: faces uncovered (no dust masks), friendly eyes with pupils, a slight smile,
  vivid outfits (`docs/crew-v2.png`).
- Engine map scan after the changes: 0 floating, 0 lodged props on all three maps.

## Animations (`docs/engine-weapon-actions.png`)
- Revolver: muzzle flip, cylinder turns a chamber per shot; reload swings the cylinder out and
  loads from the belt pouch.
- Shotgun: pump after every shot (forend slides, left hand rides it); shell-by-shell loading.
- Carbine: lever cycle; loads through the side gate. Rifle: bolt work after each shot; bolt-open
  reload from the top. Bow: real draw while aiming, arrow nocked from over the shoulder.
- Everyone flinches away from hits. Healing holsters the gun (from the last round).

## Console
Gamepad layout (Xbox names; PlayStation in brackets): R2 fire, L2 aim (with aim assist), R1
reload, L1 dodge, X [Square] melee/grab/quiet, Y [Triangle] tap throw / hold ability, B [Circle]
crouch / hold prone and closes menus, A interact, D-pad tap/hold pairs (weapon/holster,
throwable/backpack gun, torch/ammo cache, heal/resupply), L3 sprint, R3 shoulder, View satchel
(with Lucky Spin, Shop, Settings, Controls). Menus put the selection cursor on their first
button automatically.

## Lucky Spin and new paid items
- One **free spin every day** (resets 00:00 UTC) at the wheel on deck or the FREE SPIN button.
- Extra spins: **R$10** (or 5 for R$45). Prizes: Scrip, Materials, ammo kits, Ammo Cache /
  Second Wind / Shipwright tokens, a re-spin, and a 500 Scrip jackpot.
- Roblox rules for paid random items: the odds of every prize are listed on the spin screen
  before you spin or buy, and spins are not sold where PolicyService says paid random items are
  restricted (those players still get the free daily spin).
- **Ammo Crate** (R$35) / **Ammo Crate x3** (R$89): ammo for your next crossing (+8 revolver,
  +4 rifle, +4 shells, +6 arrows). At most 2 crates open per crossing, so ammo stays scarce.

# Round 2: Brinewake

- **New name: Brinewake** (no Roblox experience uses it). Store icon, three thumbnails and the
  description are in `store/` with upload steps.
- **Fixes:** crafting needs room for the whole batch (reported on the PR); spin prizes name exactly
  what they give (the "long-gun ammo" prize was an ammo kit, packed for the next crossing); a rare
  real gun prize was added. Cross / A presses the nearest prompt on every console.
- **Clearer upgrades:** station signs name the currency they take (Scrip / Materials / Salvage);
  after your first crossing a NEXT STEP card and a gold line point to whatever you can afford.
- **Stealth:** crouched or prone in tall grass you can't be seen (unless your light is on, you just
  fired, or someone is right on top of you).
- **Gun handling:** breathing sway, walk bob, aim-in lift, a weapon check when idle, harder
  recoil that rocks the whole body.
- **World:** 11 containers per mission instead of one in every room, built as real furniture.
- **Crew:** realistic proportions, hair texture, cuffs, seams, laces.
- **Cheap options:** Pocket Rounds R$5, Bandage Roll R$5, Scrip Pouch R$9, Lucky Spin x3 R$25,
  four R$19 outfits; brighter wardrobe colours.
- **New features:** 7-day login streak (rewards every day, bigger on day 7) and the Logbook:
  16 torn pages of story hidden two per mission; every 4 found pays Scrip and Materials.

# Round 3
- **Building kinds** (`MapKit.house`): house, shop (striped awning, sign, display windows), apartment
  (2-3 extra floors with balconies), garage (roll-up door, tyres, drums, tool chest), chapel (bell
  tower, coloured glass, pews), cabin. Larkspur mixes them along the street plus a chapel; Cannery
  Row gets a harbour shop and a garage. Render: `docs/engine-building-kinds.png`.
- **Masks:** every crew member wears one over the lower face: bandana (Mara navy, Sefa teal),
  respirator with orange filters (Tobias), surgical (Ines).
- **Sway:** the camera no longer drifts when you are not aiming (a hair of breathing only when
  standing still); aim sway and held-gun sway are lower.
- **Signature guns:** Mara lever carbine, Tobias recurve bow, Ines pump shotgun, Sefa bolt rifle,
  each with only a few spare rounds. A gun chosen at the Quartermaster takes the holster and your
  signature gun goes in the backpack if there is a free slot.

# Round 4
- **Movement:** Space jumps (a short hop) or **vaults** any wall, crate or ledge between about
  1 and 4.5 studs high when you face it (engine-tested on the real maps: finds low walls and
  crates, lands on the far side, refuses open ground and tall walls). Dodge moved to Left Alt
  (L1 on a controller); A on a controller jumps/vaults when there is nothing to interact with.
  Landing thud + camera dip, walking head-bob, hop and vault poses. Characters can no longer be
  tipped over or ragdolled by physics.
- **First person:** K (or Satchel > FIRST/THIRD PERSON): camera at the eyes, head and torso
  hidden, arms and gun kept.
- **Listen mode:** hold L (hold R3 on a controller; a quick tap still swaps shoulder). The screen
  greys, you creep and cannot shoot, and enemies within about 46 studs show as silhouettes
  through walls (pale = Hushed, amber = people, red = hunting you) with a ping that speeds up as
  they get closer.
- **Callouts:** the Watch and the Tidebound have names and talk: "Contact!", "Where'd they go?",
  "Wren, flank them!" (and the one ordered really circles round), "No! Dale!", "What was that?".
  A bubble over the speaker plus a subtitle with a direction arrow. Voice blips are synthesised.
- **More sounds:** voices, landing, vault, jump, listen on/off/loop/ping, birds, gulls, brass
  tinks, heavy breathing after a long sprint.
- **Pickups:** a taken item switches off its prompt and vanishes in the same instant; a second
  press can never take it twice. A partly taken stack says how many are left.

# Round 5: first person, readable UI, recoil fix, Hollow Pines
- **Recoil drift fixed.** The sideways recoil used to be added to your aim permanently, so every
  shot pushed the screen further off target. Recoil is now only an offset that springs back to
  zero; where you aimed is where you stay.
- **First person is the default** and the game is built around it (Settings > VIEW switches to
  third person; K toggles). First-person gun poses sit low and right, pointing at the crosshair,
  and rise under it when you aim (checked with a view rendered from the eye:
  `render_engine_result.py --fp`). Field of view is a setting.
- **Readable UI:** everything is built inside one scaler (bigger on big screens and consoles, and
  Settings > Text and menu size: Normal / Large / Huge), no text below 14 px before scaling, larger
  objective line and mission cards.
- **Hollow Pines rebuilt:** lakeside logging valley with a lake, dock and rowboat, a campground
  round a fire, a gas station and shop with a canopy, a sawmill, a plank bridge over the creek, a
  radio mast, wrecks and signposts along the road, 150 pines, flowers, and a rock ridge with a tree
  line instead of concrete flood walls.

# Round 6: ten new maps (13 in all)
Built on a shared `MapGen` (records loot, containers and doorways from every building, keeps props
out of buildings, assembles the map data), each checked in the real engine: it builds, a mission
sets up on it (containers, supply crates, logbook pages, doors), and the scan finds nothing floating
or lodged. Previews are in `docs/maps/`.

| Map | What it is |
|---|---|
| Saltmarsh Flats | tidal mud, wading pools, boardwalks on stilts, stilt huts, wrecked boats, reeds |
| Old Town Market | cobbled square, fountain, clock tower, shops/flats/chapel round it, stalls, bunting |
| Funfair Pier | dusk amusement pier: turning ferris wheel, carousel, big top, stalls, bumper cars, lights |
| Verdant Gardens | hedge maze, two glasshouses, fountain plaza, gazebo, statues, flower beds |
| Golden Vineyard | rolling vine rows, farmhouse, barn, wine cellar, windmill, hay, tractors |
| Dry Dock Yard | flooded dock with a half-built ship, two gantry cranes, catwalks, containers |
| Cinder Quarry | terraced pit with a ramp, crusher, excavators, trucks, conveyor, site huts |
| Whiteout Depot | snowbound railway depot, freight, locomotive, platform, water tower, falling snow |
| Lighthouse Point | cliff headland, striped lighthouse with a beam, bunkers, jetty, wreck on the rocks |
| Powerworks | cooling towers, turbine hall, transformer yard, pylons with wires, coal conveyor |

Unlocking: Cannery Row, Larkspur Street, Saltmarsh Flats, Old Town Market and Funfair Pier are
available from the start; the Chart Room project adds Hollow Pines, Verdant Gardens, Golden
Vineyard and Dry Dock Yard; the Lookout Tower adds Cinder Quarry, Whiteout Depot, Lighthouse Point
and Powerworks. Routes still pick maps at random from what the crew has unlocked.

# Round 7: rewarded video ads
Optional "watch an ad, get it free" for items the shop already sells: **Second Wind** (also
offered on the down screen), **Ammo Cache**, **Resupply Satchel**, **Pocket Rounds**, **Bandage
Roll**. Open it from the Satchel (FREE ITEMS) or the shop (FREE: WATCH AN AD). Config in
`Config/Ads.luau`, server in `AdsService` (cooldown per offer, 10 per hour), client in
`UI/AdOffers.luau`.
- Not offered, because Roblox's rewarded-ad rules forbid them: **Lucky Spin** (randomised reward)
  and **Scrip/Materials** (currency that inflates the economy).
- To turn it on: Creator Hub > Monetization > Ads > Settings > Rewarded Video > Serving enabled.
  The experience must be public, have an approved content rating and about 2,000 unique monthly
  visitors; until then no ad is "available" and the buttons stay hidden.
- Ad rewards arrive as the normal purchase receipt (Robux spent: 0), so they use the same safe,
  once-only grant path as purchases.
