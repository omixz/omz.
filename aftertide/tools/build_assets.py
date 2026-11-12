#!/usr/bin/env python3
"""Builds every 3D asset for AFTERTIDE from code (no third-party models).

Output:
  aftertide/assets/<Pack>.glb        upload these (tools/upload_assets.py or Studio Import 3D)
  aftertide/assets/previews/*.png    turnaround renders of every asset
  src/shared/Config/MeshMeta.luau    placement data the game uses to fit meshes on skeletons

Usage: python3 tools/build_assets.py [PackName ...]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets")
PREV = os.path.join(OUT, "previews")
META = os.path.join(ROOT, "src", "shared", "Config", "MeshMeta.luau")

from sculpt import creature, human, props  # noqa: E402
from sculpt.kit import Pack  # noqa: E402


def c(r, g, b):
    return (r / 255, g / 255, b / 255)


CREW = {
    "mara": (dict(skin=c(198, 160, 130), top=c(58, 76, 84), pants=c(48, 46, 42), boots=c(46, 36, 30), gear=c(92, 84, 64), hat="beanie", hatColor=c(70, 56, 48), hair=c(58, 40, 30), mask=c(120, 110, 94), scarf=c(138, 70, 52)), dict(b=0.95, f=1.0, height=1.0)),
    "tobias": (dict(skin=c(150, 108, 82), top=c(112, 74, 44), pants=c(52, 58, 66), boots=c(40, 32, 26), gear=c(70, 74, 60), hat="cap", hatColor=c(52, 58, 54), hair=c(30, 24, 20), mask=c(86, 82, 74), toolbelt=True, kneePads=c(40, 40, 40)), dict(b=1.12, f=0.0, height=1.03)),
    "ines": (dict(skin=c(110, 76, 58), top=c(122, 40, 38), pants=c(40, 44, 50), boots=c(34, 30, 30), gear=c(150, 140, 120), hat="bun", hair=c(26, 20, 18), mask=c(200, 196, 186), iris=c(40, 26, 18)), dict(b=0.98, f=1.0, height=0.97)),
    "sefa": (dict(skin=c(134, 94, 66), top=c(150, 118, 52), pants=c(56, 62, 58), boots=c(30, 40, 44), gear=c(58, 70, 66), hat="hood", hatColor=c(130, 102, 46), hair=c(24, 20, 18), mask=c(64, 78, 84)), dict(b=1.05, f=0.0, height=1.0)),
}

# Factions (original, not from any other game):
#  The Harbour Watch - an ex-port-authority militia: slate fatigues, plate carriers, helmets.
#  The Tidebound - a cult that worships the Pall: undyed salt-white robes, cowls, ash tide-lines.
FACTIONS = {
    "WatchRifleman": (dict(skin=c(168, 128, 100), top=c(70, 78, 82), pants=c(64, 70, 72), boots=c(30, 28, 26), gear=c(60, 64, 58), hat="helmet", hatColor=c(58, 64, 62), hair=c(40, 30, 24), vest=c(52, 58, 56), gloves=c(34, 32, 30), kneePads=c(44, 48, 46), pack=False), dict(b=1.12, f=0.0)),
    "WatchScout": (dict(skin=c(120, 86, 64), top=c(78, 84, 80), pants=c(64, 70, 72), boots=c(30, 28, 26), gear=c(60, 64, 58), hat="cap", hatColor=c(48, 54, 56), hair=c(24, 20, 18), mask=c(60, 64, 66), vest=c(56, 62, 60), gloves=c(34, 32, 30)), dict(b=0.98, f=1.0)),
    "TideboundArcher": (dict(skin=c(186, 150, 120), top=c(214, 206, 188), pants=c(150, 140, 120), boots=c(60, 48, 36), gear=c(120, 104, 80), hat="cowl", hatColor=c(205, 198, 180), hair=c(80, 60, 44), facePaint=c(70, 72, 74), style="robe", pack=False), dict(b=0.95, f=1.0)),
    "TideboundHook": (dict(skin=c(140, 104, 80), top=c(196, 188, 170), pants=c(140, 130, 110), boots=c(54, 44, 34), gear=c(110, 96, 74), hat="cowl", hatColor=c(190, 182, 164), hair=c(30, 24, 20), facePaint=c(60, 62, 64), style="robe", pack=False), dict(b=1.15, f=0.0)),
}

HUSHED = ["Drifter", "Rusher", "Seeker", "Bellwether", "Tidewalker"]


def build(only=None):
    os.makedirs(PREV, exist_ok=True)
    meta = {}
    packs = {}

    def want(name):
        return not only or name in only

    if want("Crew"):
        p = Pack("Crew")
        for cid, (outfit, body) in CREW.items():
            segs, J = human.build_segments(outfit, **body)
            p.add_rig("Crew_" + cid, segs, human.segment_bounds, human.R15_ANCHORS, J, cell=0.055, fine={"Head": 0.03, "RHand": 0.028, "LHand": 0.028}, rename=human.r15_name)
        packs["Crew"] = p
    if want("Factions"):
        p = Pack("Factions")
        for fid, (outfit, body) in FACTIONS.items():
            segs, J = human.build_segments(outfit, **body)
            segs = creature.human_to_enemy(segs)
            p.add_rig("Faction_" + fid, segs, creature.enemy_bounds, creature.ENEMY_ANCHORS, J, cell=0.065, fine={"Head": 0.034, "RightLowerArm": 0.034, "LeftLowerArm": 0.034})
        packs["Factions"] = p
    if want("Hushed"):
        p = Pack("Hushed")
        for i, k in enumerate(HUSHED):
            segs, J = creature.build_segments(k, rng_seed=i + 1)
            p.add_rig("Hushed_" + k, segs, creature.enemy_bounds, creature.ENEMY_ANCHORS, J, cell=0.062, fine={"Head": 0.035, "RightLowerArm": 0.034, "LeftLowerArm": 0.034})
        packs["Hushed"] = p
    all_props = props.assets()
    groups = {
        "Weapons": [k for k in all_props if k.startswith("Weapon_") or k == "Flashlight"],
        "Nature": [k for k in all_props if k.startswith(("Grass", "Fern", "Bush", "Pine", "DeadTree", "Rock", "Boulder"))],
        "Props": [k for k in all_props if k.startswith(("Car", "Rubble", "Barrel"))],
    }
    for gname, keys in groups.items():
        if not want(gname):
            continue
        p = Pack(gname)
        for k in keys:
            cell, layers = all_props[k]
            p.add_prop(k, cell, layers)
        packs[gname] = p

    for name, p in packs.items():
        pm = p.write(os.path.join(OUT, name + ".glb"), PREV)
        for kit, entry in pm.items():
            entry["pack"] = name
            meta[kit] = entry

    # merge with existing metadata (when rebuilding only some packs)
    # (kept in assets/ under version control: deleting it would drop the packs not rebuilt)
    meta_json = os.path.join(OUT, "MeshMeta.json")
    existing = {}
    if os.path.exists(meta_json):
        existing = json.load(open(meta_json))
    existing.update(meta)
    json.dump(existing, open(meta_json, "w"))
    write_lua(existing)


def lua(v, indent=1):
    pad = "\t" * indent
    if isinstance(v, dict):
        items = []
        for k, x in v.items():
            key = k if k.isidentifier() else f'["{k}"]'
            items.append(f"{pad}{key} = {lua(x, indent + 1)},")
        return "{\n" + "\n".join(items) + "\n" + "\t" * (indent - 1) + "}"
    if isinstance(v, list):
        return "{ " + ", ".join(lua(x, indent + 1) for x in v) + " }"
    if isinstance(v, str):
        return '"' + v + '"'
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    return repr(v)


def write_lua(meta):
    body = lua(meta)
    with open(META, "w") as f:
        f.write("--!nonstrict\n-- GENERATED by tools/build_assets.py - do not edit by hand.\n")
        f.write("-- Placement data for the sculpted meshes (segment anchors, layer centres/sizes,\n")
        f.write("-- materials, colours). MeshKit uses it to fit each mesh onto its skeleton.\n")
        f.write("return " + body + "\n")


if __name__ == "__main__":
    build(sys.argv[1:] or None)
