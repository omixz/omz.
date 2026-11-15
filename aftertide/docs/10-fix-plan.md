# 10. Fix plan (playtest rounds 1 to 5)

## Why earlier fixes didn't land

Nothing in my environment can run Roblox, so every fix so far was written blind and only
checked by reading the code. When a fix rested on a wrong guess about the engine (how the
importer orients meshes, what overwrites `Motor6D.Transform`, what takes Tab), it failed
silently, and you only found out by playtesting. More blind fixes would repeat that.

**The change:** prove fixes in the real engine before you see them.

| Step | What | Needs from you |
|---|---|---|
| V1 | **In-game diagnostics (F2):** every client and server warning/error, the animation system's state, the last keys and actions received, and how the 3D packs were fitted, on screen in a box you can copy. | Nothing. |
| V2 | **Automated engine tests (Open Cloud).** `tools/publish_place.py` publishes the place; `tools/engine_test.py` runs test scripts inside the real Roblox engine on that place and reads the results. Tests: load packs and fit a crew body, then measure every joint gap; resolve the sky textures; build every map and report floating or overlapping objects; build the Meridian and check nothing intersects. | Publish once (File > Publish to Roblox), send the Place ID, and add the key permissions listed below. |

Key permissions (Creator Hub > Open Cloud > API Keys > your key > add, for this experience):
*Place Management (universe-places) Write*, *Luau Execution Sessions Write*,
*Developer Products Write*, *Game Passes Write*.

## The open issues and how each gets fixed and proven

| Issue | Most likely cause | Fix | How it is proven |
|---|---|---|---|
| Body: arms not attached, faces off | Pieces fitted with the wrong correction, or posed by Roblox's animation instead of ours | Engine test reports the importer transform and joint gaps per piece; I correct from numbers, not guesses | V2 joint-gap test reads 0 gaps |
| No gun / heal / prone animation | Roblox's Animator overwrote our joints (removed last round), or our animator stops on an error | F2 shows whether the animator runs and its error, if any | F2 screenshot plus the V2 animator test |
| Satchel won't open | Menu keys lost to Roblox core scripts / a failed binding | Menu keys (I, Tab, F1, F2, P) handled by a direct input listener, not ContextActionService | F2 shows the key arriving and the panel opening |
| Prone | Depends on the animator plus the hold-C input | As above | F2 shows "Stance Prone" |
| Generic sky | Decal-to-image lookup failing, so the sky never gets textures | V2 resolves every sky face in the engine and prints the image IDs; fall back to the image ID itself | V2 sky test |
| Objects lodged in the Meridian (boards, door, generator, lockers) | Hand-placed coordinates overlap the bridge | Meridian rebuilt from a layout table with a built-in overlap check | V2 overlap test reads 0 |
| Floating drawers / props | Ground lookups on stacked geometry | Settle-to-surface (done) plus the V2 floating-object scan on every map | V2 map scan |
| Random deaths / clipping out | Stale hip height, dodges through walls | Fixed last round, plus the safety net | F2 logs every safety-net rescue |

## New features in this round

1. **Missions** (3 new types, more variety):
   - **Medicine Run:** find the marked medical caches inside buildings, then extract.
   - **Restore the Signal:** repair 3 radio relays. Repairing is loud, so expect company.
   - **Burn the Nests:** destroy salt nests with fire, explosives or enough damage.
2. **Quest board on the Meridian:** daily and weekly challenges (e.g. "Quiet 10 Hushed", "Finish a crossing unseen") paying Scrip and Materials.
3. **Meridian projects:** a new persistent resource, **Materials**, comes from missions (plus leftover Salvage at the end of a crossing). Spend it with Scrip on projects that physically add rooms to the ferry (Workshop, Infirmary, Radio Room, Armory, Chart Room, Lookout). Projects also unlock mission types and the third map.
4. **Robux skip:** a "Shipwright's Crew" token (and a 3-pack) completes any one project instantly, without the materials.
5. **Leaderboard:** `leaderstats` in the player list (Wins, Best Pall), plus a global top-10 board on the Meridian (OrderedDataStore).

## Order of work

1. V1 diagnostics and direct-input menu keys (no dependencies).
2. Meridian rebuilt from a layout table (fixes the lodged objects; makes room for project rooms).
3. Materials, projects, rooms, mission unlocks, skip tokens.
4. New mission types and the quest board.
5. Leaderboard.
6. V2 test harness and tests, ready to run as soon as the place is published.
7. With the Place ID and permissions: publish, run the tests, fix from real numbers, then hand
   you a build that has passed the engine tests.
