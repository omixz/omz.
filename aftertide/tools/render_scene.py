#!/usr/bin/env python3
"""Renders the parts exported by tests/engine/scene.luau: a shaded perspective view (painter's
algorithm, sun + sky light) so layouts can be reviewed without Studio.
  python3 tools/render_scene.py scene.json out.png [--eye x,y,z] [--at x,y,z] [--fov 60]
Positions are relative to the scene origin. Mesh parts are drawn as their bounding boxes."""
import argparse
import json

import numpy as np
from PIL import Image, ImageDraw

FACES = [((1, 0, 0), [(1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)]),
         ((-1, 0, 0), [(-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)]),
         ((0, 1, 0), [(-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)]),
         ((0, -1, 0), [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
         ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
         ((0, 0, -1), [(1, -1, -1), (-1, -1, -1), (-1, 1, -1), (1, 1, -1)])]
WEDGE = [((1, 0, 0), [(1, -1, -1), (1, -1, 1), (1, 1, 1)]),
         ((-1, 0, 0), [(-1, -1, 1), (-1, -1, -1), (-1, 1, 1)]),
         ((0, -1, 0), [(-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)]),
         ((0, 0, 1), [(-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)]),
         ((0, 0.7071, -0.7071), [(1, -1, -1), (-1, -1, -1), (-1, 1, 1), (1, 1, 1)])]


def look_at(eye, at):
    f = at - eye
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("scene")
    ap.add_argument("out")
    ap.add_argument("--eye", default="-40,45,70")
    ap.add_argument("--at", default="0,0,0")
    ap.add_argument("--fov", type=float, default=55)
    ap.add_argument("--size", default="1600,900")
    ap.add_argument("--ground", default=None, help="r,g,b,y: a flat ground/sea plane at height y")
    ap.add_argument("--ss", type=int, default=2, help="supersampling factor (anti-aliasing)")
    a = ap.parse_args()
    data = json.load(open(a.scene))
    if isinstance(data, list):
        data = data[0]
    origin = np.array(data.get("origin", [0, 0, 0]), float)
    W, H = map(int, a.size.split(","))
    outW, outH = W, H
    W, H = W * a.ss, H * a.ss
    eye = np.array(list(map(float, a.eye.split(","))))
    at = np.array(list(map(float, a.at.split(","))))
    r, u, f = look_at(eye, at)
    focal = (H / 2) / np.tan(np.radians(a.fov) / 2)
    sun = np.array([0.45, 0.8, 0.35])
    sun /= np.linalg.norm(sun)
    polys = []
    if a.ground:
        gr, gg, gb, gy = map(float, a.ground.split(","))
        data["parts"].insert(0, {"c": [eye[0] + origin[0], gy - 0.5 + origin[1], eye[2] + origin[2], 1, 0, 0, 0, 1, 0, 0, 0, 1], "s": [3000, 1, 3000], "col": [gr, gg, gb], "t": 0, "m": "Ground", "sh": "Block"})
    for p in data["parts"]:
        c = p["c"]
        pos = np.array(c[0:3]) - origin
        R = np.array(c[3:12]).reshape(3, 3)
        half = np.array(p["s"]) / 2
        col = np.array(p["col"], float)
        faces = WEDGE if p.get("sh") == "Wedge" else FACES
        if p.get("sh") in ("Ball", "Cylinder"):
            half = half * 0.85
        for n, verts in faces:
            nw = R @ np.array(n, float)
            pts = [pos + R @ (np.array(v, float) * half) for v in verts]
            centre = sum(pts) / len(pts)
            if np.dot(nw, eye - centre) <= 0:
                continue
            cam = [(np.dot(q - eye, r), np.dot(q - eye, u), np.dot(q - eye, f)) for q in pts]
            if min(z for _, _, z in cam) < 0.5:
                if p.get("m") != "Ground":
                    continue
                # clip the ground quad to the near plane
                keep = [(x, y, max(z, 0.5)) for x, y, z in cam]
                cam = keep
            scr = [(W / 2 + x / z * focal, H / 2 - y / z * focal) for x, y, z in cam]
            light = 0.42 + 0.58 * max(0.0, float(np.dot(nw, sun))) + 0.12 * max(0.0, nw[1])
            if p.get("m") == "Neon":
                light = 1.4
            shade = np.clip(col * light, 0, 255)
            depth = np.linalg.norm(centre - eye) if p.get("m") != "Ground" else 1e9
            # aerial perspective: far faces fade toward the sky haze
            fog = min(1.0, max(0.0, (np.linalg.norm(centre - eye) - 120) / 600)) if p.get("m") != "Ground" else 0
            shade = shade * (1 - fog) + np.array([200, 220, 236]) * fog
            alpha = 1 - p.get("t", 0)
            polys.append((depth, scr, tuple(int(v) for v in shade), alpha))
    polys.sort(key=lambda t: -t[0])
    img = Image.new("RGB", (W, H), (214, 232, 246))
    sky = ImageDraw.Draw(img)
    for y in range(H):
        k = min(1.0, y / (H * 0.6))
        sky.line([(0, y), (W, y)], fill=(int(70 + 150 * k), int(130 + 104 * k), int(210 + 38 * k)))
    over = Image.new("RGBA", (W, H))
    for depth, scr, shade, alpha in polys:
        if alpha >= 0.99:
            ImageDraw.Draw(img).polygon(scr, fill=shade, outline=tuple(max(0, v - 25) for v in shade))
        else:
            layer = Image.new("RGBA", (W, H))
            ImageDraw.Draw(layer).polygon(scr, fill=shade + (int(255 * alpha),))
            img.paste(Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB"))
    img = img.resize((outW, outH), Image.LANCZOS)
    img.save(a.out)
    print("wrote", a.out, len(polys), "faces")


if __name__ == "__main__":
    main()
