# 8. Audio: the AFTERTIDE sound pack

Every sound in `aftertide/audio/` (42 files) was **synthesised from scratch** by
`tools/make_sounds.py`: gunshots, reloads, impacts, glass, explosions, fire, doors,
footsteps (concrete and water), melee, heartbeat, the Hushed (breathing, growls, the Rusher
shriek, the Seeker's salt-grind, the Tidewalker groan, the Bellwether hum, dispersal),
ambience (wind, sea, drone), tension music and stingers, and UI ticks. No samples were used,
so you own all of it and there's nothing to license.

Roblox only plays audio uploaded to Roblox, so there's one manual step:

## Upload (about 10 minutes)

1. In Studio: **View → Asset Manager → Bulk Import** (the import button), then select
   **all 42 `.ogg` files** in `aftertide/audio/`. Uploading audio is free; Roblox checks
   each file, which can take a few minutes.
2. In the Asset Manager's **Audio** folder, right-click each sound → **Copy ID**.
3. Paste the IDs in, either way:
   - **In Studio:** open **ReplicatedStorage → Shared → Config → Sounds** and put each ID
     next to its name, e.g. `Gun_revolver = "rbxassetid://1234567890",`
   - **Or with the tool:** make `ids.txt` with one line per sound (`Gun_revolver 1234567890`),
     then run `python3 tools/fill_sound_ids.py ids.txt` and `python3 tools/build_place.py`.
4. Play. You'll hear the pack. Any name left empty is just silent.

Monthly audio upload limits depend on whether your account is ID-verified; check the
Creator Hub if Studio refuses an upload.

**Shortcut:** if you create an Open Cloud API key (Creator Hub → Open Cloud → API Keys,
permission *Assets: Read & Write*), `tools/upload_assets.py` uploads all 44 and fills in the IDs (see [doc 9](09-models-factions-maps.md)).

## Changing a sound

Each sound is a small function in `tools/make_sounds.py`. Tweak it (pitch, length,
reverb), run `python3 tools/make_sounds.py`, and re-upload that file.
