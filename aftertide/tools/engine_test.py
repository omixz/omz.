#!/usr/bin/env python3
"""Runs a Luau test script inside the real Roblox engine on the published AFTERTIDE place
(Open Cloud Luau Execution) and prints its return value and logs.
  python3 tools/engine_test.py tests/engine/assets.luau [--out result.json]
Needs the API key permission: Luau Execution Sessions Write (for this experience)."""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(HERE, "place_config.json")
KEY = os.environ.get("ROBLOX_API_KEY", "injected-by-proxy")
API = "https://apis.roblox.com/cloud/v2"


def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={"x-api-key": KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{e.code} {e.reason}: {e.read().decode(errors='replace')[:800]}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("script")
    ap.add_argument("--out")
    ap.add_argument("--set", action="append", default=[], help="NAME=luau-expression globals for the test, e.g. SCENE_TARGET='\"HollowPines\"'")
    args = ap.parse_args()
    cfg = json.load(open(CONFIG))
    if not cfg.get("placeId"):
        raise SystemExit("Publish first: python3 tools/publish_place.py --place-id <id>")
    prelude = open(os.path.join(os.path.dirname(HERE), "tests", "engine", "_prelude.luau")).read()
    sets = "".join(f"{kv.split('=', 1)[0]} = {kv.split('=', 1)[1]}\n" for kv in args.set)
    script = prelude + "\n" + sets + open(args.script).read()
    task = call("POST", f"{API}/universes/{cfg['universeId']}/places/{cfg['placeId']}/luau-execution-session-tasks", {"script": script, "timeout": "280s"})
    path = task["path"]
    for _ in range(150):
        state = task.get("state")
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            break
        time.sleep(2)
        task = call("GET", f"{API}/{path}")
    logs = call("GET", f"{API}/{path}/logs")
    for chunk in logs.get("luauExecutionSessionTaskLogs", []):
        for line in chunk.get("messages", []):
            print("LOG", line)
    print("STATE", task.get("state"))
    if task.get("error"):
        print("ERROR", json.dumps(task["error"])[:2000])
    results = (task.get("output") or {}).get("results")
    if args.out:
        json.dump(results, open(args.out, "w"), indent=1)
        print("results ->", args.out)
    else:
        print(json.dumps(results, indent=1)[:20000])
    sys.exit(0 if task.get("state") == "COMPLETE" else 1)


if __name__ == "__main__":
    main()
