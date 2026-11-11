# AFTERTIDE *(working title)*

A cinematic, third-person stealth-survival roguelike for Roblox. This folder holds the
pre-production design pack: what we are building, how, how it makes money, how we
keep it legally clean, and in what order we build it.

**Status: playable roguelike build: crossings of 3 encounters + finale, guns, scavenging,
crafting, workbench and homebase. Waiting for its first Studio play-test.**
Solo dev, US$0 budget, 1 to 4 player co-op, Moderate maturity.

## Play it now

1. Install Roblox Studio (free).
2. **File → Open from File…** → [`build/Aftertide.rbxlx`](build/Aftertide.rbxlx).
3. Press **Play**. Pick a crew member and a perk, then hold **E** at the tide chart.

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
| 8 | [Audio](docs/08-audio.md) | The original synthesised sound pack (42 sounds) and how to upload it |

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
