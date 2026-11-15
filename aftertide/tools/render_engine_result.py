#!/usr/bin/env python3
"""Draws what the engine tests saw: every sculpted piece placed exactly where the real
Roblox engine put it (assets.luau / animator.luau results), front and side views.
Where the engine gave us the imported mesh's real vertices, those are drawn (the truth);
otherwise our own mesh data is drawn at the engine's placement (marked "assumed").
  python3 tools/render_engine_result.py result.json out.png"""
import json
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def glb_meshes():
    meshes = {}
    for f in os.listdir(os.path.join(ROOT, "assets")):
        if not f.endswith(".glb"):
            continue
        d = open(os.path.join(ROOT, "assets", f), "rb").read()
        n = struct.unpack("<I", d[12:16])[0]
        j = json.loads(d[20:20 + n])
        B = d[20 + n + 8:]
        for node in j["nodes"]:
            prim = j["meshes"][node["mesh"]]["primitives"][0]
            a = j["accessors"][prim["attributes"]["POSITION"]]
            v = j["bufferViews"][a["bufferView"]]
            pts = np.frombuffer(B[v["byteOffset"]:v["byteOffset"] + v["byteLength"]], np.float32).reshape(-1, 3)
            col = j["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorFactor"][:3]
            meshes[node["name"]] = (pts, col)
    return meshes


def cframe(c):
    p = np.array(c[0:3])
    R = np.array(c[3:12]).reshape(3, 3)
    return p, R


def main(path, out):
    res = json.load(open(path))
    if isinstance(res, list):
        res = res[0]
    meshes = glb_meshes()
    samples = {s["name"]: np.array(s["points"]) for s in res.get("samples", []) if isinstance(s, dict) and "points" in s}
    clouds = []
    for p in res["pieces"]:
        pos, R = cframe(p["cframe"])
        size = np.array(p["size"])
        if p["name"] in samples and p.get("meshSize"):
            local = samples[p["name"]] * (size / np.maximum(np.array(p["meshSize"]), 1e-6))
            col = (0.9, 0.5, 0.3)
        else:
            src = meshes.get(p.get("source") or "")
            if src is None:
                continue
            pts, col = src
            lo, hi = pts.min(0), pts.max(0)
            # our own geometry, uniformly scaled; the part's frame includes the importer
            # correction (FitRot), which rotates native -> sculpt axes, so undo it here
            k = np.linalg.norm(size) / max(np.linalg.norm(hi - lo), 1e-6)
            local = (pts - (lo + hi) / 2) * k
            if p.get("fitRot"):
                _, F = cframe(p["fitRot"])
                R = R @ F.T
        world = local @ R.T + pos
        clouds.append((world, col))
    allp = np.concatenate([c[0] for c in clouds])
    lo, hi = allp.min(0), allp.max(0)
    W, H = 900, 900
    img = Image.new("RGB", (W * 2, H), (24, 26, 28))
    draw = ImageDraw.Draw(img)
    scale = 0.9 * H / max(hi[1] - lo[1], 1e-6)
    for view, (ax, flip) in enumerate(((0, 1), (2, -1))):  # front (x,y), side (z,y)
        order = []
        for world, col in clouds:
            depth = world[:, 2 if ax == 0 else 0]
            for q, dz in zip(world, depth):
                order.append((dz * flip, q, col))
        order.sort(key=lambda t: -t[0])
        for _, q, col in order:
            x = W * view + W / 2 + (q[ax] - (lo[ax] + hi[ax]) / 2) * scale * flip
            y = H / 2 - (q[1] - (lo[1] + hi[1]) / 2) * scale
            c = tuple(int(255 * min(1, v * 1.4) ** (1 / 2.2)) for v in col)
            draw.ellipse([x - 1.5, y - 1.5, x + 1.5, y + 1.5], fill=c)
    img.save(out)
    print("wrote", out, "(", len(clouds), "pieces;", len(samples), "with real engine vertices )")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
