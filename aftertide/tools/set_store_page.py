#!/usr/bin/env python3
"""Sets the experience's name and description (Open Cloud). The root place's name is what
Roblox shows as the game's title; the universe call also works if the key has universe:write.
  python3 tools/set_store_page.py"""
import json
import os
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CFG = json.load(open(os.path.join(HERE, "place_config.json")))
KEY = os.environ.get("ROBLOX_API_KEY", "injected-by-proxy")

NAME = "Brinewake"
DESCRIPTION = """Brinewake: a co-op survival game for 1-4 players. The Pall rolled in off the sea and the town went quiet. Now the Hushed walk the streets, and the Harbour Watch and the Tidebound fight over what is left.

You are the crew of the Meridian, a ferry turned home. Cross the flooded coast stop by stop, scavenge, sneak and fight your way to the Breakwater.

FEATURES
- Stealth or go loud: crouch and go prone in tall grass, take enemies quietly from behind, grab a human enemy as a shield.
- Scarce ammo, real gun handling: revolver, lever carbine, pump shotgun, bolt rifle and recurve bow, each with its own handling and reloads.
- Every mission is different: 9 mission types on 3 maps, rolled at random, with modifiers like fog and nightfall.
- Craft on the fly: arrows, spikes, salt bombs, field dressings.
- Upgrade the Meridian: build an Infirmary, Workshop, Armory and more, and unlock new missions and maps.
- Unlock guns at the Quartermaster, plus daily and weekly quests and a global leaderboard.
- Free Lucky Spin every day.
- Play on PC, mobile, Xbox and PlayStation.

HOW TO START
Pick a crew member, then walk to the gold light on the deck, the SET SAIL table.

Controls: press F1 on keyboard, or open the satchel on a controller (View / Touchpad)."""


def call(method, url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method=method)
    req.add_header("x-api-key", KEY)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.status, r.read().decode()[:300]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")[:300]


u, p = CFG["universeId"], CFG["placeId"]
print("place:", call("PATCH", f"https://apis.roblox.com/cloud/v2/universes/{u}/places/{p}?updateMask=displayName,description", {"displayName": NAME, "description": DESCRIPTION}))
print("universe:", call("PATCH", f"https://apis.roblox.com/cloud/v2/universes/{u}?updateMask=displayName,description", {"displayName": NAME, "description": DESCRIPTION}))
