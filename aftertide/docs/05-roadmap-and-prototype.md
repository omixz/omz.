# 5. Development Roadmap & First Playable Prototype

## 5.1 Assumptions

- The team is you plus contracted art, animation and audio when needed. Durations
  below assume **one main developer working about 20 to 30 hours a week**. A full-time
  team of 3 to 4 can compress the total by about half.
- **Each stage has an exit gate.** We don't move on until the gate passes. Building
  more content on a camera that feels bad is the most common way projects like this
  fail.

## 5.2 Stages

| # | Stage | Duration | Deliverables | Exit gate |
|---|---|---|---|---|
| 1 | **Concept, IP, feasibility** | 2 to 3 wks | This design pack; title search started; Rojo repo scaffold; asset register created | You approve the vision, IP and monetisation. The title has no obvious conflict. |
| 2 | **Visual direction** | 3 to 4 wks (in parallel with stage 3) | Mood boards; 1 character concept; Hushed concept; colour script; a lighting test scene (fog + lantern) running on a mid-range phone | A screenshot test: 5 people say it doesn't look like a Roblox game. Hits 30 fps on mobile. |
| 3 | **Movement & camera prototype** | 4 to 6 wks | Custom camera, stances, speed states, noise radius, placeholder mannequin rig, gamepad/KB/touch | **Feel gate:** 10 blind testers rate the movement 4 out of 5 or better. No camera clipping in the test course. |
| 4 | **First playable environment** | 4 to 6 wks | One grey-box encounter map with prototype stealth AI (see §5.3) | **Fun gate:** testers want "one more go" and describe the tension unprompted |
| 5 | **Character & animation systems** | 8 to 10 wks | Custom rig pipeline; first hero character; locomotion blending, IK, takedown pairs; FACS face | Animation passes side-by-side review with reference footage. No foot sliding. |
| 6 | **Encounters & enemy AI** | 10 to 12 wks | All 5 Hushed types; 5 encounter types; PacingDirector; 3 maps | Every encounter type is fun on its own. AI budget under 2 ms. |
| 7 | **Progression & replayability** | 6 to 8 wks | Run generation, tide chart, salt, skills, Keepsakes, modifiers, Pall Level, finale | Testers voluntarily play 3 runs in a row. Runs feel different from each other. |
| 8 | **Hideout & character select** | 4 to 6 wks | The *Meridian*, crew cabins, workshop, chart room, character select, 4 characters | Ferry phase takes under 2 min on average and feels like relief, not a chore |
| 9 | **Save systems & multiplayer** | 6 to 8 wks | ProfileStore, migrations, ferry checkpoints, Harbour lobby, parties, duo co-op | No data loss across 1,000 simulated sessions. Duo co-op is stable at 20 enemies. |
| 10 | **Monetisation** | 4 to 6 wks | Catalogue, CommerceService, the Purser's Office, first cosmetic set, Founder pass, analytics | Receipts are idempotent in testing. Purchase flow tested on all platforms. Legal pricing review done. |
| 11 | **Optimisation, testing, launch** | 8 to 12 wks | Performance passes, closed alpha → open beta, soft launch, the legal gate (doc 4 §4.8) | D1 retention above 30% and D7 above 10% in beta. Crash rate under 1%. |

**Total: about 14 to 20 months** to a quality launch for a small team. Stages 2 and 3
overlap, and art production runs alongside stages 5 to 8.

Launch content target: 4 characters, 8 maps, 5 encounter types plus the finale, about
30 Keepsakes, 4 difficulty tiers, about 40 cosmetics.

## 5.3 First playable prototype ("Slice 0", covering stages 3 and 4)

**Question it answers:** *Does sneaking past silent things in fog on Roblox feel tense
and premium?*

### In scope

| Area | Scope |
|---|---|
| Character | One mannequin rig (placeholder, owned by us) playing Mara, with Tide Sense |
| Camera | Over-the-shoulder spring camera, collision, shoulder swap, aim and crouch states |
| Movement | Walk/jog/sprint × stand/crouch, vaulting low cover, noise radius visualisation (debug) |
| Map | **"Cannery Row"**: one grey-box encounter about 200 × 200 studs. Fish cannery interior, loading yard, flooded drain. Fog with Atmosphere and fog cards. |
| Enemies | 4 to 6 **Drifters**: patrol, hear noise, see (cone + raycast), suspicion meter, investigate, chase, search, return to patrol |
| Stealth tools | Throwable bottle (noise lure), tall-grass and dark-area concealment, torch toggle (light makes you visible) |
| Interaction | Quieting takedown from behind (placeholder animation), shove, 3 resource types, 1 craftable (bottle) |
| Objective | **Salvage**: collect 5 supply crates, then reach the extraction point. Fail if caught 3 times. |
| HUD | Noise ring, detection indicators, minimal prompts, all custom UI |
| Audio | Footsteps by surface, a 2-state music loop (calm / detected), fog reverb zone |
| Tech | Rojo project, typed net layer, server-authoritative pickups and takedowns, debug overlay (AI states, perception rays) |

### Out of scope (for now)

Real art, the final rig, data saving, the ferry hideout, run structure, co-op, other
enemy types, monetisation, the lobby, the mobile control polish pass. Mobile **must
run**, but its controls only need to work at this stage.

### Success criteria

1. Over 70% of 10 or more playtesters rate "tension" 4 out of 5 or better.
2. Testers can explain why they were detected; every detection is readable.
3. 60 fps on a mid PC, 30 fps on a mid phone, client memory under 700 MB on mobile.
4. Zero client-trusted outcomes (code review checklist).

### Placeholder assets needed

- A mannequin rig with an R15-compatible bone layout (we build it in Blender, so we
  own it).
- Grey-box kit: walls, crates, doors, fences. Built from Parts and our own simple
  meshes.
- About 10 placeholder SFX from a commercially licensed library (logged in the
  register).
- **No Creator Store free models**, not even for grey-boxing.

## 5.4 What comes next

Once you approve this pack, the next delivery is **Stage 3 code**:

1. The Rojo scaffold (`default.project.json`, `wally.toml`, the folder tree from
   doc 2 §2.3, Selene/StyLua configs, a CI lint workflow).
2. `Shared/Net` (typed remotes plus a rate limiter), `Util/Spring`, a `Signal` and a
   `Trove`.
3. `CameraController`, `MovementController` and `Config/Movement`, plus a test course
   (stairs, slopes, tight corridors, low cover) to tune against.
4. Step-by-step Studio setup instructions: what goes where, which properties to set,
   and how to test.
5. Known issues and tuning notes for the feel gate.

## 5.5 Decisions needed from you

1. **Title:** go with AFTERTIDE and start the clearance search, or pick an alternate?
2. **Team & budget:** solo, or a budget for contract art, mocap and composer? This
   changes the stage 2 and 5 timelines.
3. **Co-op at launch:** I recommend duo. Do you agree?
4. **Maturity target:** I recommend Moderate. Do you agree?
5. **Business entity:** set up a Pty Ltd before contractors start? (Recommended.)
