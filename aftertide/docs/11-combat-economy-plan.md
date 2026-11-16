# 11. Combat, weapons and economy plan (round 6)

## Weapons: start small, earn the rest
- **Everyone starts every crossing with only the Service Revolver** (6 in the cylinder + 4 spare)
  and their melee. The character select screen and controls card say so.
- **Unlock** the Lever Carbine, Pump Shotgun, Recurve Bow and Bolt Rifle permanently at the
  **Quartermaster** on the Meridian, paid with Scrip earned from missions.
- **Holster system:** two quick slots (sidearm + one long gun) swap fast (1 / 2). Every other
  unlocked gun you bring rides in your **backpack**: getting it out (key 4, or from the
  satchel) means kneeling and digging for 2.4 s, unable to shoot. You choose your holstered long
  gun and backpack guns at the Quartermaster. Backpack space: 1 gun, +1 with the Armory project.
- **Guns are harder:** more hip-fire spread and sway, more recoil, slower aim-in, longer reloads.

## Ammo is scarce
- Lower reserve caps (revolver 12, rifle 8, shells 6, arrows 8).
- Containers and loose loot give 1 to 2 rounds, rarely more, and ammo shows up less often.
- Smaller Resupply and Ammo Cache refills.
- Human enemies sometimes drop a few rounds of what they carried: worth the risk to grab.
- Crafting stays the way to make arrows; Black Salt and scrap matter more.

## Combat
- **Leg shots stun:** a hit in the leg drops the enemy to a knee for about 1.3 s (longer with
  heavy guns), then they limp. Works on the Hushed and human enemies.
- **Stealth melee:** a melee strike on an enemy that hasn't noticed you, from behind, is a sneak
  strike: triple damage, near-silent, and it staggers.
- **Grab (human shield):** sneak up behind a Harbour Watch or Tidebound fighter and press F to
  grab them. While you hold them:
  - you move slowly and can still fire your revolver;
  - their friends hesitate and reposition instead of firing through their own;
  - F again is a silent takedown, and after 8 s you shove them away, stunned;
  - the Hushed don't care, so grabbing doesn't protect you from them.

## Economy: two currencies, two uses
- **Scrip** (end of every mission) is spent at the **Quartermaster store**: gun unlocks and
  crossing kits (extra rounds, dressings, throwables delivered at the start of your next
  crossing). It also buys Wardrobe outfits.
- **Materials** (end of every mission, plus leftover Salvage) are spent only on **Meridian projects**.
- Mission payouts are bigger, and the results screen lists both.

## Meridian projects that matter
| Project | Effect |
|---|---|
| Deck Lights | +10% Scrip from missions (crew morale) |
| Generator Room | +20 Salvage at the start of every crossing |
| Workshop | Workbench 25% cheaper; +1 from every arrow, spike and salt bomb you craft |
| Infirmary | +15 max health, +1 Field Dressing at the start; Medicine Run missions |
| Radio Room | 3 route choices; Restore the Signal missions |
| Armory | +1 backpack gun slot, Quartermaster 15% cheaper; Burn the Nests missions |
| Chart Room | Hollow Pines; +15% Materials from missions |
| Lookout Tower | A Tide Sense pulse for the whole crew at the start of every encounter |

## Missions: 9 types, always random
| # | Mission | Goal | Available |
|---|---|---|---|
| 1 | Salvage | 4 supply crates, then extract | always |
| 2 | Lantern Watch | keep the lantern lit through the waves | always |
| 3 | Drift | survive while hunted, then extract | always |
| 4 | **Cut the Head Off** (new) | kill a marked elite (Watch captain, Tidebound priest or Hushed matriarch), then extract | always |
| 5 | **Bring Them Home** (new) | find a survivor and lead them out alive | always |
| 6 | Medicine Run | medical caches inside buildings | Infirmary |
| 7 | Restore the Signal | repair 3 loud radio relays | Radio Room |
| 8 | Burn the Nests | destroy salt nests | Armory |
| 9 | The Breakwater | finale | end of every crossing |

Routes are drawn at random from what's unlocked. The same mission type is never offered twice
on one chart, and never repeats straight after you've just played it. Map and faction are rolled
independently.

## Testing
Everything here passes both static checkers (structure, and no undefined names; the scope
checker caught 3 real ordering bugs while this was built). Engine tests (doc 10) run once the
place is published and the key has access; a combat test (leg stun, grab hesitation) will be added
to that suite then.
