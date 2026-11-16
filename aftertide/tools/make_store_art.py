#!/usr/bin/env python3
"""Store-page art for Brinewake: icon (512x512) and three thumbnails (1920x1080), composed from
the sculpted crew (assets/Crew.glb) and engine scene renders (tools/render_scene.py output).
  python3 tools/make_store_art.py <ferry.png> <street.png>   -> store/*.png"""
import json
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from sculpt import preview  # noqa: E402

OUT = os.path.join(ROOT, "store")
BOLD = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
SEMI = "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf"
KEY = (255, 0, 255)


def crew_parts(cid, only=None):
    d = open(os.path.join(ROOT, "assets", "Crew.glb"), "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + n])
    B = d[20 + n + 8:]

    def acc(i, dt, k):
        a = j["accessors"][i]
        v = j["bufferViews"][a["bufferView"]]
        return np.frombuffer(B[v["byteOffset"] + a.get("byteOffset", 0):][:a["count"] * k * np.dtype(dt).itemsize], dt).reshape(-1, k)
    parts = []
    for node in j["nodes"]:
        nm = node["name"]
        if nm.startswith("Crew_" + cid + "_") and (only is None or only in nm):
            prim = j["meshes"][node["mesh"]]["primitives"][0]
            v = acc(prim["attributes"]["POSITION"], np.float32, 3).copy() + np.array(node.get("translation", [0, 0, 0]))
            ia = j["accessors"][prim["indices"]]
            f = acc(prim["indices"], {5125: np.uint32, 5123: np.uint16}[ia["componentType"]], 1).reshape(-1, 3)
            col = j["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorFactor"][:3]
            parts.append((v, f, col))
    return parts


def cutout(cid, size, yaw=20, only=None):
    tmp = os.path.join(OUT, "_tmp.png")
    preview.render(crew_parts(cid, only), tmp, size=size, yaw=yaw, pitch=4, bg=KEY, views=1)
    im = Image.open(tmp).convert("RGBA")
    a = np.array(im)
    mask = (np.abs(a[..., 0].astype(int) - 255) + a[..., 1] + np.abs(a[..., 2].astype(int) - 255)) < 60
    a[mask, 3] = 0
    os.remove(tmp)
    return Image.fromarray(a)


def text(draw, xy, s, size, fill, font=BOLD, anchor="la", shadow=True, stroke=0):
    f = ImageFont.truetype(font, size)
    if shadow:
        draw.text((xy[0] + size // 18, xy[1] + size // 18), s, font=f, fill=(0, 0, 0, 150), anchor=anchor)
    draw.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=(20, 30, 40))


def gradient(w, h, top, bottom):
    g = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(g)
    for y in range(h):
        k = y / (h - 1)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)))
    return g


def vignette(im, strength=0.45):
    w, h = im.size
    y, x = np.mgrid[0:h, 0:w]
    r = np.sqrt(((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2)
    k = np.clip(1 - strength * np.clip(r - 0.6, 0, 1), 0, 1)[..., None]
    return Image.fromarray((np.array(im.convert("RGB")) * k).astype(np.uint8))


def title_block(im, sub):
    d = ImageDraw.Draw(im, "RGBA")
    d.rectangle([0, im.size[1] - 250, im.size[0], im.size[1]], fill=(8, 20, 34, 150))
    text(d, (80, im.size[1] - 225), "BRINEWAKE", 150, (255, 214, 110), stroke=4)
    text(d, (86, im.size[1] - 62), sub, 46, (236, 244, 250), font=SEMI)


def main(ferry, street):
    os.makedirs(OUT, exist_ok=True)
    crew = {c: cutout(c, (560, 900)) for c in ["mara", "tobias", "ines", "sefa"]}

    # 1. the Meridian + crew
    t1 = vignette(Image.open(ferry).convert("RGB").resize((1920, 1080)), 0.35).convert("RGBA")
    for i, c in enumerate(["sefa", "tobias"]):
        im = crew[c].resize((470, 756))
        t1.alpha_composite(im, (1180 + i * 330, 160))
    title_block(t1, "Co-op survival · 1-4 players · free daily spin")
    t1.convert("RGB").save(os.path.join(OUT, "thumbnail_1_meridian.png"))

    # 2. the crew
    t2 = gradient(1920, 1080, (40, 110, 170), (250, 170, 110)).convert("RGBA")
    d2 = ImageDraw.Draw(t2, "RGBA")
    for k in range(6):  # sea bands
        y = 800 + k * 40
        d2.rectangle([0, y, 1920, 1080], fill=(20, 110 + k * 8, 150 + k * 6, 60))
    for i, c in enumerate(["mara", "tobias", "ines", "sefa"]):
        im = crew[c].resize((520, 836))
        t2.alpha_composite(im, (90 + i * 440, 110))
    title_block(t2, "Pick your crew: stealth, traps, medic, heavy")
    t2.convert("RGB").save(os.path.join(OUT, "thumbnail_2_crew.png"))

    # 3. the street
    t3 = vignette(Image.open(street).convert("RGB").resize((1920, 1080)), 0.4).convert("RGBA")
    t3.alpha_composite(crew["mara"].resize((520, 836)), (1300, 170))
    title_block(t3, "Sneak. Scavenge. Survive the Pall.")
    t3.convert("RGB").save(os.path.join(OUT, "thumbnail_3_street.png"))

    # icon: Mara on a sunset sea, title on a band
    icon = gradient(512, 512, (52, 120, 196), (252, 178, 106)).convert("RGBA")
    di = ImageDraw.Draw(icon, "RGBA")
    di.ellipse([306, 70, 436, 200], fill=(255, 226, 150, 255))  # sun
    for k in range(5):
        y = 330 + k * 26
        di.rectangle([0, y, 512, 512], fill=(16, 100 + k * 10, 150 + k * 8, 90))
    head = cutout("mara", (700, 1100))
    bbox = head.getbbox()
    head = head.crop((bbox[0], bbox[1], bbox[2], bbox[1] + int((bbox[3] - bbox[1]) * 0.5)))
    head = head.resize((int(head.width * 420 / head.height), 420))
    icon.alpha_composite(head, ((512 - head.width) // 2, 40))
    di = ImageDraw.Draw(icon, "RGBA")
    di.rectangle([0, 420, 512, 512], fill=(8, 20, 34, 200))
    text(di, (256, 466), "BRINEWAKE", 66, (255, 214, 110), anchor="mm", stroke=2)
    icon.convert("RGB").save(os.path.join(OUT, "icon_512.png"))
    print("wrote", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
