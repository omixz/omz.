# 1. Vision & Original IP

## 1.1 My reading of the vision

You want a run-based stealth-survival game where every encounter is tense, where you
are always short of something, and where the camera, animation, lighting and sound
make it feel like a console game. Roblox is the engine and the storefront, not the
look.

Three things decide whether that works on Roblox:

1. **Feel beats fidelity.** We can't match a PS5 renderer, and we won't try to. We
   can match how it *feels*: camera weight, animation timing, audio, pacing, UI
   restraint. Those are design and code problems, and code we control.
2. **Constraints should become identity.** Roblox has hard limits: no custom shaders,
   a mostly mobile audience and tight memory. The setting is built so those limits look
   intentional. Fog hides draw distance. Night and lantern light hide low-poly
   silhouettes. Tide-flooded streets break maps into small, dense spaces.
3. **Short runs and co-op keep players coming back.** Roblox players play in shorter
   sessions and in groups more than console players do. A *crossing* (one run) should
   take 25 to 40 minutes, be resumable at the ferry, and support **1 to 4 players**
   (duo is the baseline we tune difficulty around).

### Where I'm pushing back

| Your ask | My recommendation | Why |
|---|---|---|
| "Premium console" visuals | Aim for the best-looking game in its Roblox category, with stylised realism | No custom shaders, limited post-processing, and about 60% or more of players are on phones. Chasing photorealism means poor mobile performance and poor retention. |
| Optional paid character packs | Every playable character is **earned by playing**. Paid packs are cosmetic story packs for those characters. | A character with unique abilities sold for Robux is pay-to-win, whatever we call it. |
| Subscription from day one | Launch it about 8 to 12 weeks after release, once we have shown a monthly content cadence | Recurring billing needs recurring value, or it churns and generates refunds and bad reviews. |
| Solo-focused like the inspiration | **Decided:** solo to 4-player co-op. Enemy count scales with party size. Roblox hosts every server for free and adds more automatically. | Roblox discovery rewards social play, and invites are a growth loop. |
| Build everything in parallel | Prove the camera, movement and one encounter first | If the feel isn't there, nothing else matters. |

---

## 1.2 Title & brand

**Working title: AFTERTIDE**

Alternates, in case clearance fails: *Pale Harbour*, *The Hushed Coast*, *Saltward*.

- **Tagline:** "The sea took the noise. Don't give it yours."
- **Logo direction:** a hand-stencilled wordmark like ferry hull markings, with a
  tide-line rule through the middle. Off-white on dark slate.
- **Clearance:** the title is **not cleared**. See [doc 4](04-ip-compliance.md) §4.2.
  Search the trade mark registers before spending money on logo art.

## 1.3 The world

**The Marrow Coast** is a fictional temperate coastline of estuaries, causeways,
fishing towns, salt flats and a container port. It is deliberately not a real city or
country. The architecture mixes weatherboard, corrugated iron and brutalist concrete
port buildings, a look that reads as "southern hemisphere coastal" without copying any
real place.

**The Pall.** Eleven years ago a pale, cold fog rose off the sea and never fully
left. It breathes with the tide: it thins at low tide and floods inland at high tide.
Anyone who sleeps inside it, or stays in it too long without a mask, becomes
**Hushed**.

**The Hushed** are not zombies or infected people, and nothing about them is gory.
They are silent, upright, salt-crusted figures whose faces are smoothed over with a
pale crust. They don't bite, bleed or eat. They are drawn to **light and noise**,
because those are what the Pall has taken from them. When one is defeated it does not
die visibly. It **slumps and disperses into the fog** as a burst of salt and mist.
This keeps the game non-graphic, helps with the content-maturity rating, and gives us
a visual signature nobody else has.

**Survivors** live by tide tables. Low tide is when you move. The tide chart, the
rising Pall and salt as currency all come from this one premise.

### Tone & themes

Quiet dread, endurance and found family. Moments of warmth in the ferry hideout make
each departure land. The story is told through the environment, radio logs, chalk tide
marks and survivor notes, not cutscenes. That's cheaper to make and suits Roblox better.

## 1.4 The hideout: the *Meridian*

A beached roll-on/roll-off car ferry, wedged on a sandbar, rusted, and lit by strings
of salvaged bulbs. It's the hub between encounters and it is where all of these live:

- **Chart Room:** pick the next encounter on the tide chart.
- **Workshop (vehicle deck):** craft and upgrade.
- **Crew Cabins:** character select and wardrobe. Each character has a customisable
  cabin.
- **Purser's Office:** the in-world shop (see [doc 3](03-monetisation.md) §3.8).
- **Galley:** the social space in co-op: radio, logbook, photo wall.

Restoring the *Meridian* over many runs (lights, decks, the radio mast) is the main
long-term progression you can see. It's mostly cosmetic, with small horizontal unlocks.

## 1.5 Playable characters (the crew)

All original. Each has one **signature ability** with a cooldown, one **passive** and
a **skill tree** that resets every run. None of them is better than the others; they
play differently.

| Character | Background | Signature ability | Passive | Playstyle |
|---|---|---|---|---|
| **Mara Kell** (40s) | Former harbour pilot | **Tide Sense:** briefly see Hushed through thin fog as salt-glints | Moves quieter in shallow water | Stealth and scouting |
| **Tobias Ruane** (30s) | Ferry engineer, built the hideout's generator | **Rattle Box:** deployable clockwork noisemaker | Crafts traps with one fewer part | Distraction and traps |
| **Ines Okafor-Hale** (50s) | Paramedic, runs the ferry's sick bay | **Steady Hands:** fast self- or ally-revive and a brief calm that lowers your noise | Healing items +25% | Sustain and co-op support |
| **Sefa Talataina** (30s) | Fisher, net-maker | **Throw Net:** pins a Hushed for a few seconds | Can carry one extra throwable | Control and escapes |
| **Wren Calder** (60s) | Retired land surveyor | **Survey:** marks resources and exits in a radius | Finds 1 extra part per container | Exploration and economy |
| **Dashiell Moreau** (20s) | Ex surf lifesaver | **Riptide:** shoulder-charge that knocks back a group | Sprints quieter | Breakout and aggression |

At launch: Mara, Tobias, Ines and Sefa. Wren and Dashiell unlock through play
milestones, and new characters arrive with seasons, always earnable for free.

### 1.5.1 Loadouts & perks (built in Slice 0)

Every character starts each crossing with **their own loadout**, an **innate perk**, and
**one starting perk chosen from three** in the crew cabin. This is the core of
why runs feel different by character. Data lives in `src/shared/Config/Characters.luau`.

| Character | Starting loadout | Innate perk | Choose one starting perk |
|---|---|---|---|
| **Mara** | 8 Salt Shot · 2 Bottle · 1 Bandage | *Shallow Step*: wading makes no extra noise | *Quiet Hands* (Quietings 40% faster) · *Long Sense* (Tide Sense +50% radius) · *Light Foot* (crouching 30% quieter) |
| **Tobias** | 5 Salt Shot · 2 Bottle · 1 Bandage · 3 Scrap | *Tinkerer*: recipes cost 1 part less | *Loud Decoy* (Rattle Box +40% radius) · *Thick Skin* (−15% damage) · *Spare Shot* (+4 Salt Shot) |
| **Ines** | 4 Salt Shot · 1 Bottle · 3 Bandage | *Field Medic*: healing +25%, revived crew get +30 HP | *Calm Breath* (10% quieter) · *Second Opinion* (+15 s bleed-out) · *Triage* (ability recharges 25% faster) |
| **Sefa** | 6 Salt Shot · 3 Bottle · 1 Bandage | *Deep Pockets*: +1 bottle capacity | *Strong Arm* (bottles heard 30% further) · *Heavy Net* (net pins 50% longer) · *Sea Legs* (sprint 8% faster) |

Stage 7 extends this into a full **in-run perk tree** (3 branches × 5 perks per character,
bought with salt) and **alternate loadouts** unlocked by character mastery (for example,
Mara's "Lookout" loadout at mastery 5). These are sidegrades, never strictly better.

Design guard rails: no character resembles any copyrighted protagonist in look,
silhouette, backstory, item pairing or voice. See the IP checklist in doc 4.

## 1.6 Enemies (the Hushed)

| Type | Senses | Behaviour | Counter |
|---|---|---|---|
| **Drifter** | Hearing (good), sight (poor in fog) | Wanders tide paths and investigates noise | Sneak or distract |
| **Lantern-eye** | Sight (excellent, sees light) | Slow. Turns toward any light source | Lights off, approach from behind |
| **Bellwether** | Hearing | Lets out a low hum that alerts every Hushed in range | Highest priority to silence |
| **Tidewalker** | Hearing + vibration | Big and slow, can't be stunned by a shove; only nets or traps work | Avoid, trap, outlast |
| **Mire** | Touch | Lies still under water and grabs anyone who wades through | Read the ripples, throw something in |
| **Tollkeepers** *(humans, post-launch)* | Sight + radio | Patrols that capture rather than kill. Losing to them costs supplies, not the run | Evade, bribe with salt |

**Finale:** *The Choir*, a mass of Hushed around the Breakwater lighthouse, humming
in sync. It's a stealth-and-light puzzle encounter, not a damage race.

How the player beats them: stealth first (crouch, reeds, darkness, bottles, the
**Quieting** from behind), and when that fails, **guns**. Weapons are fictional and
stylised, and the targets are non-human Hushed that burst into salt, never blood.
Gunshots are **loud** noise events that pull every Hushed nearby, so going loud is
always a trade-off.

### 1.6.1 Combat, scavenging & crafting (built)

| System | What it does |
|---|---|
| **Weapons** | Service Revolver (sidearm, everyone), plus a long gun per character: Recurve Bow (silent, arrows drop), Pump Shotgun (pellets, falloff), Bolt Rifle (precise), Lever Carbine (fast). Magazines + reserve ammo, timed reloads, hip/aim spread, movement penalty, recoil climb, headshots, stagger, aim zoom. Long guns sit on your back and sidearms on your hip until drawn (keys 1/2/3). |
| **Throwables** | Bottle (distraction), **Flare Pot** (burning area), **Fog Pot** (smoke that blocks sight and stuns), **Salt Bomb** (proximity trap that explodes). |
| **Tide Spike** | A crafted tool. Quiet a Hushed **from the front**, or break free automatically when grabbed. |
| **Scavenging** | Search drawers, lockers, toolboxes and ammo crates (they open). Loose items glint in the fog. What doesn't fit stays on the floor for a crewmate. |
| **Crafting** | 6 parts (Cloth, Alcohol, Black Salt, Scrap, Tape, Canister) shared between recipes: Field Dressing and Flare Pot both need Cloth + Alcohol, so every craft is a choice. |
| **Workbench** (per crossing) | Spend Salvage on weapon parts (damage, reload, baffle/suppressor, scope, magazine, stability), satchel and ammo-pouch upgrades, a faster holster, and your character's other perks. |
| **Homebase** (permanent) | Spend Scrip (earned by playing) to repair the *Meridian*: deck lights, generator (+Salvage), sick bay (+Dressing), workshop (−15% workbench), radio mast (3 routes on the chart), armory (choose your long gun). |

## 1.7 The run: a *Crossing*

```
 Ferry  ──►  Reach I (3 nodes, pick 1 per step)  ──►  Ferry
 Ferry  ──►  Reach II                            ──►  Ferry
 Ferry  ──►  Reach III                           ──►  Ferry  ──►  The Breakwater (finale)
```

- **Tide chart.** Each Reach shows 2 or 3 branching nodes. You can see each node's
  type, modifier and reward before you choose. Every choice is a trade-off between
  risk, reward and tide cost.
- **Pall Level** (1 to 10) is the run's difficulty meter. It goes up after every
  encounter and faster if you take "long" routes. It controls the number and types of
  enemies, fog density and spawn budget.
- **Between encounters** you go back to the *Meridian* to craft, spend **salt** (the
  run currency) on skills, swap a **Keepsake**, and choose the next node. This takes
  about 2 minutes and is the rhythm of the run: tension, then relief, then tension.
- **Failure** ends the run. You keep meta-progress (logbook entries, mastery XP,
  *Meridian* repairs), so a lost run is never wasted time.
- **Target length:** 6 to 8 encounters at 3 to 5 minutes each, plus the ferry phases,
  is about 25 to 40 minutes.

### Encounter types

These are original names and structures, chosen to avoid mirroring any existing mode's
encounter list.

| Encounter | Goal | Core tension |
|---|---|---|
| **Salvage** | Collect a quota of supplies, then reach the extraction | Greed against how fast the fog is rising |
| **Lantern Watch** | Keep a signal lantern lit until the tide turns (waves) | The light draws Hushed in. You defend it with traps and positioning |
| **Drift** | A Tidewalker tracks you. Cross the map to the exit | Being chased, but sound can still be used against it |
| **Lost Signal** | Find a stranded survivor by radio and bring them back | Escorting someone slows you down and makes noise |
| **Silent Passage** | Cross without raising an alert. Each alert worsens the reward | Pure stealth |
| **Salt Cache** *(rare)* | A locked hoard with a puzzle to open it | Exploration and lore |
| **The Breakwater** *(finale)* | Re-light the lighthouse past the Choir | Everything at once |

### Modifiers (one or two per node)

*Heavy Pall* (shorter sight range for you and them), *Squall* (rain masks your
footsteps but your light flickers), *Spring Tide* (flooded routes, Mires), *Blackout*
(no ambient light), *Echoing* (sound travels twice as far), *Scavenged Out* (half the
loot, double the salt), *Moonbreak* (fog clears: you can see them and they can see
you).

### Random events (ferry and node level)

A trader barge docks (barter only), a radio distress call (optional side node), a
generator failure at the ferry (crafting costs more next turn), a lone survivor offers
a Keepsake in exchange for supplies.

## 1.8 Progression

**Within a run (resets each time):**

- **Salt** buys skill-tree nodes for your character, 3 branches of 5 nodes each.
- **Parts** (cloth, wire, glass, powder, tape, scrap) feed crafting: bandage, flare,
  bottle, salt-charge, net, Rattle Box (Tobias), and so on.
- **Keepsakes:** about 30 build-changing perks found or bought during a run, such as
  "Lighthouse Keeper's Watch: Tide Sense recharges on every Quieting". Keepsakes are
  where the variety between runs comes from.

**Persistent (meta):**

- **Logbook:** lore entries, enemy notes and maps. Collecting them is its own goal.
- **Character mastery** (levels 1 to 20 per character). Unlocks **cosmetics** and a
  few **sidegrade** starting loadouts, never raw stat increases.
- ***Meridian* restoration:** spend "Ferry Scrip", earned only through play, on hideout
  repairs. Some repairs unlock run options, such as a second starting Keepsake choice.
- **Tide Ledger** challenges: weekly and daily objectives with modest rewards and no
  login-streak punishment.
- **Difficulty tiers:** *Calm, Swell, Storm, King Tide* (plus custom modifiers after
  the first finale clear). Higher tiers give cosmetic prestige only.

**The rule against grind:** a skilled new player can beat the game on *Calm* with
zero meta-unlocks. Meta-progress adds variety and style, not required power.

## 1.9 Art direction

- **Palette:** desaturated slate, sea-glass green and bone white. The only warm
  colour is light: lanterns, flares, ferry bulbs. **Warm means safe and dangerous at
  the same time**, which is the core visual idea.
- **Shapes:** heavy, practical, weathered. Ropes, buoys, tide-stained concrete,
  corrugated iron.
- **Characters:** realistic proportions (about 7.5 heads tall), layered practical
  clothing, a custom skinned-mesh rig with FACS faces. No default Roblox avatar parts.
- **UI:** diegetic where possible. Inventory in a waxed canvas satchel, the map is a
  real tide chart, and health shows as breathing and a vignette. The flat HUD is
  limited to a minimal compass and the noise ring.
- **Audio identity:** sparse, low strings and detuned brass. **Silence is the music**
  in stealth. When detected, the score swells; when you break line of sight, it falls
  away. The Hushed make no vocal sounds at all except the Bellwether's hum, and that
  silence is part of the brand.
