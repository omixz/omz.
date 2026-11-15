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
