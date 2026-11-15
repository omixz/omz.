#!/usr/bin/env python3
"""Publishes build/Aftertide.rbxlx as a new version of the AFTERTIDE place (Open Cloud).
  python3 tools/publish_place.py                 # uses tools/place_config.json
  python3 tools/publish_place.py --place-id 123  # first time: also fills the config
Needs the API key permission: universe-places Write (for this experience)."""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CONFIG = os.path.join(HERE, "place_config.json")
KEY = os.environ.get("ROBLOX_API_KEY", "injected-by-proxy")


def call(method, url, body=None, ctype=None):
    req = urllib.request.Request(url, data=body, method=method, headers={"x-api-key": KEY, **({"Content-Type": ctype} if ctype else {})})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{e.code} {e.reason}: {e.read().decode(errors='replace')[:500]}")


def config(place_id=None):
    cfg = json.load(open(CONFIG)) if os.path.exists(CONFIG) else {"placeId": 0, "universeId": 0}
    if place_id:
        cfg["placeId"] = int(place_id)
        cfg["universeId"] = int(call("GET", f"https://apis.roblox.com/universes/v1/places/{place_id}/universe")["universeId"])
        json.dump(cfg, open(CONFIG, "w"), indent=1)
    if not cfg.get("placeId"):
        raise SystemExit("No place yet: publish once in Studio, then run with --place-id <id>")
    return cfg


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--place-id")
    args = ap.parse_args()
    cfg = config(args.place_id)
    body = open(os.path.join(ROOT, "build", "Aftertide.rbxl"), "rb").read()
    res = call("POST", f"https://apis.roblox.com/universes/v1/{cfg['universeId']}/places/{cfg['placeId']}/versions?versionType=Published", body, "application/octet-stream")
    print("published version", res.get("versionNumber"), "of place", cfg["placeId"])


if __name__ == "__main__":
    main()
