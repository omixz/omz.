# AFTERTIDE *(working title)*

A cinematic, third-person stealth-survival roguelike for Roblox. This folder holds the
pre-production design pack: what we are building, how, how it makes money, how we
keep it legally clean, and in what order we build it.

**Status: Stage 1 (concept, IP, feasibility). No game code yet, by design.**

| # | Document | What it decides |
|---|----------|-----------------|
| 1 | [Vision & original IP](docs/01-vision-and-ip.md) | Title, world, characters, enemies, run loop, encounters, progression |
| 2 | [Technical architecture](docs/02-technical-architecture.md) | Places, services, networking, AI, stealth, data, performance budgets, engine limits |
| 3 | [Monetisation & revenue](docs/03-monetisation.md) | Every product, its Robux price, revenue maths, the in-world shop |
| 4 | [IP & legal compliance](docs/04-ip-compliance.md) | Australian copyright/trade mark, Roblox rules, asset/music licensing, risk register, checklist |
| 5 | [Roadmap & first prototype](docs/05-roadmap-and-prototype.md) | Stage-by-stage plan with exit criteria, and the exact scope of the first playable |

Tools:

- [`tools/revenue_model.py`](tools/revenue_model.py): the revenue model behind doc 3.
  Change the assumptions at the top and run `python3 tools/revenue_model.py`.

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
  a seasonal Tide Pass, a later subscription, and private servers. No pay-to-win, no paid
  random rewards, no fake discounts.
- **The plan:** prove the camera, movement and one stealth encounter feel premium
  before building anything else.
