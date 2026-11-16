#!/usr/bin/env python3
"""Creates AFTERTIDE's developer products and game passes on Roblox (Open Cloud, beta APIs)
from src/shared/Config/Commerce.luau, then writes the new IDs back into that file.

  python3 tools/create_products.py --place-id 1234567890      # the published place's ID
  python3 tools/create_products.py --universe-id 987654321    # or the experience (universe) ID
  python3 tools/create_products.py --place-id 123 --dry-run   # list what would be created

Only items whose ID is still 0 are created, so it is safe to run again.
The API key (ROBLOX_API_KEY, or injected by the cloud proxy) needs these permissions on the
experience: developer-product:write and game-pass:write.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
COMMERCE = os.path.join(ROOT, "src", "shared", "Config", "Commerce.luau")
KEY = os.environ.get("ROBLOX_API_KEY", "injected-by-proxy")

ITEM = re.compile(
    r'\n\t\t(?P<key>\w+) = \{\n\t\t\t(?P<idfield>productId|passId) = (?P<id>\d+),\n'
    r'\t\t\tname = "(?P<name>[^"]*)",\n\t\t\tprice = (?P<price>\d+),\n\t\t\tdesc = "(?P<desc>[^"]*)",'
)


def call(method, url, fields=None):
    data, headers = None, {"x-api-key": KEY}
    if fields is not None:
        boundary = uuid.uuid4().hex
        body = bytearray()
        for k, v in fields.items():
            body += f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
        body += f"--{boundary}--\r\n".encode()
        data = bytes(body)
        headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"{e.code} {e.reason}: {e.read().decode(errors='replace')[:500]}")


def universe_from_place(place_id):
    return int(call("GET", f"https://apis.roblox.com/universes/v1/places/{place_id}/universe")["universeId"])


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--place-id", type=int)
    g.add_argument("--universe-id", type=int)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    universe = args.universe_id or universe_from_place(args.place_id)
    print("universe", universe)

    src = open(COMMERCE).read()
    todo = [m for m in ITEM.finditer(src) if m["id"] == "0"]
    if not todo:
        print("Nothing to create: every product and pass already has an ID.")
        return
    for m in todo:
        kind = "pass" if m["idfield"] == "passId" else "product"
        print(f"{kind:8} {m['key']:22} R$ {m['price']:>4}  {m['name']}")
    if args.dry_run:
        return

    created = 0
    for m in todo:
        fields = {"name": m["name"][:50], "description": m["desc"][:1000], "price": m["price"], "isForSale": "true"}
        try:
            if m["idfield"] == "passId":
                res = call("POST", f"https://apis.roblox.com/game-passes/v1/universes/{universe}/game-passes", fields)
                new_id = res.get("gamePassId")
            else:
                res = call("POST", f"https://apis.roblox.com/developer-products/v2/universes/{universe}/developer-products", fields)
                new_id = res.get("productId")
            if not new_id:
                raise RuntimeError("no id in response: " + json.dumps(res)[:300])
        except RuntimeError as e:
            print(f"  {m['key']} FAILED: {e}", file=sys.stderr)
            continue
        # write the id back right away so a later failure doesn't lose it
        src = open(COMMERCE).read()
        pattern = rf"(\n\t\t{m['key']} = \{{\n\t\t\t{m['idfield']} = )0,"
        src = re.sub(pattern, rf"\g<1>{new_id},", src, count=1)
        open(COMMERCE, "w").write(src)
        created += 1
        print(f"  {m['key']} -> {new_id}")
    print(f"created {created} of {len(todo)}")
    subprocess.run([sys.executable, os.path.join(HERE, "build_place.py")], check=True)


if __name__ == "__main__":
    main()
