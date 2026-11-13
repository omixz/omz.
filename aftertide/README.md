# AFTERTIDE *(working title)*

A cinematic, third-person stealth-survival roguelike for Roblox. This folder holds the
pre-production design pack: what we are building, how, how it makes money, how we
keep it legally clean, and in what order we build it.

**Status: feature-complete vertical slice.** Crossings of 3 encounters + finale on three maps,
the Hushed and two human factions, gunplay with hit zones and ragdolls, scavenging, crafting,
workbench, homebase, sculpted 3D models and sounds (uploaded to Roblox), a cosmetic wardrobe
and run-aid store. **Next: the first full Studio play-test, then creating the Robux products.**
Solo dev, US$0 budget, 1 to 4 player co-op, Moderate maturity.

## Play it now

1. Install Roblox Studio (free).
2. **File → Open from File…** → [`build/Aftertide.rbxlx`](build/Aftertide.rbxlx).
3. Press **Play**. Pick a crew member and a perk, then hold **E** at the tide chart.

**Controls:** WASD move · Shift sprint · C crouch (hold C: prone) · Space dodge (dive while sprinting) ·
RMB aim (Shift while aiming = hold breath) · LMB fire · R reload · 1/2/3 long gun / sidearm /
holster · F Quieting / melee · G throw, Z next throwable · Q ability · H heal · T flashlight ·
V Ammo Cache · B Resupply · I / Tab satchel · X swap shoulder · P settings. Gamepad and touch work too.

**Before publishing:** play a full crossing in Studio (with *Game Settings > Security >
Enable Studio Access to API Services* on to test saving), then follow doc 3 to create the
products and doc 6 for the publishing checklist.

Publishing, products, server size and the free asset pipeline: [doc 6](docs/06-publishing.md).

| # | Document | What it decides |
|---|----------|-----------------|
| 1 | [Vision & original IP](docs/01-vision-and-ip.md) | Title, world, characters, enemies, run loop, encounters, progression |
| 2 | [Technical architecture](docs/02-technical-architecture.md) | Places, services, networking, AI, stealth, data, performance budgets, engine limits |
| 3 | [Monetisation & revenue](docs/03-monetisation.md) | Every product, its Robux price, revenue maths, the in-world shop |
| 4 | [IP & legal compliance](docs/04-ip-compliance.md) | Australian copyright/trade mark, Roblox rules, asset/music licensing, risk register, checklist |
| 5 | [Roadmap & first prototype](docs/05-roadmap-and-prototype.md) | Stage-by-stage plan with exit criteria, decisions made, and what Slice 0 includes |
| 6 | [Play, publish & grow for $0](docs/06-publishing.md) | Studio setup, publishing, maturity form, developer products, free assets, launch checklist |
| 7 | [Realistic characters & graphics](docs/07-characters-and-graphics.md) | Free pipeline for realistic crew models, Cinematic/Balanced/Performance presets, PlayStation/Xbox |
| 8 | [Audio](docs/08-audio.md) | The original synthesised sound pack (44 sounds) and how to upload it |
| 9 | [Models, factions & maps](docs/09-models-factions-maps.md) | The generated 3D model packs, uploading them (Open Cloud), Harbour Watch & Tidebound, the three maps |

## Code layout

```
src/shared/   → ReplicatedStorage.Shared       config (Config/*.luau), Net, Stats, utilities
src/server/   → ServerScriptService.Server     Main + Services/* (authoritative game logic)
src/client/   → StarterPlayerScripts.Client    Main + Controllers/* (camera, movement, input, FX) + UI/*
```

Designers mostly touch `src/shared/Config/`: characters, items, enemies, modifiers, prices.

## Tools

- [`tools/build_place.py`](tools/build_place.py): rebuilds `build/Aftertide.rbxlx` from `src/`
  (or use Rojo with `default.project.json`).
- [`tools/check_luau.py`](tools/check_luau.py): static checks (block balance, cross-module calls).
- [`tools/build_assets.py`](tools/build_assets.py): sculpts the original 3D packs into `assets/*.glb`.
- [`tools/upload_assets.py`](tools/upload_assets.py): uploads models + sounds via Open Cloud and fills in the IDs.
- [`tools/revenue_model.py`](tools/revenue_model.py): the revenue model behind doc 3.

After changing anything in `src/`, run `python3 tools/check_luau.py && python3 tools/build_place.py`.

## The short version

- **The world:** eleven years ago a sea fog called **the Pall** rolled over the Marrow
  Coast. People caught in it became **the Hushed**: silent, salt-crusted sleepwalkers
  drawn to light and noise. Survivors live by the tides.
- **The run:** you leave a beached car ferry (the hideout), cross a branching tide chart
  of encounters as the Pall rises, return to the ferry between encounters to craft and
  upgrade, and finish at the Breakwater.
- **The feel:** over-the-shoulder camera, grounded movement, stealth first, sound as a
  resource. The fog is both the story and how we hit performance targets on Roblox.
- **The money:** cosmetics priced directly in Robux, character story packs (cosmetic),
  a seasonal Tide Pass, a later subscription, private servers, and capped **run aids**
  (Second Wind extra life, Resupply ammo): once per crossing, also earned free. No paid
  random rewards and no fake discounts.
- **The plan:** prove the camera, movement and one stealth encounter feel premium
  before building anything else.
