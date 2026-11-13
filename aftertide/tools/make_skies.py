#!/usr/bin/env python3
"""Paints AFTERTIDE's skyboxes (one per map + the ferry) into assets/sky/<preset>_<face>.png.

Built to be seamless however Roblox orients the faces:
  * colour depends only on true elevation (identical on all four side faces)
  * the four side faces are the same image, tiling horizontally, so any edge meets an
    identical edge: no seam whatever the face order or mirroring
  * painted clouds live in a band near the horizon; the top and bottom faces are plain
    gradients, so their rotation can't show a seam
Overhead clouds come from Roblox's volumetric Clouds; the sun is the engine's own sun."""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "sky")
N = 1024

PRESETS = {
    # zenith, mid, horizon, below-horizon haze, cloud lit, cloud shade, cloud cover (0..1), band top (deg)
    "ferry": dict(zenith=(58, 70, 96), mid=(150, 140, 150), horizon=(236, 176, 130), haze=(120, 104, 100), lit=(248, 196, 160), shade=(118, 100, 108), cover=0.55, band=28, seed=1),
    "cannery": dict(zenith=(128, 138, 148), mid=(176, 184, 190), horizon=(214, 218, 220), haze=(150, 156, 158), lit=(222, 224, 226), shade=(132, 138, 144), cover=0.8, band=34, seed=2),
    "larkspur": dict(zenith=(78, 124, 178), mid=(160, 178, 196), horizon=(250, 214, 168), haze=(176, 152, 128), lit=(255, 238, 214), shade=(176, 156, 150), cover=0.42, band=24, seed=3),
    "night": dict(zenith=(8, 11, 20), mid=(20, 26, 40), horizon=(46, 52, 66), haze=(14, 16, 22), lit=(70, 78, 96), shade=(14, 16, 24), cover=0.5, band=22, seed=5),
    "pines": dict(zenith=(130, 154, 176), mid=(188, 200, 208), horizon=(226, 230, 230), haze=(176, 184, 186), lit=(240, 242, 242), shade=(170, 178, 186), cover=0.6, band=20, seed=4),
}


def noise(shape, seed, lo, hi):
    """Periodic band-limited noise (tiles horizontally and vertically)."""
    rng = np.random.default_rng(seed)
    h, w = shape
    fy = np.fft.fftfreq(h)[:, None] * h
    fx = np.fft.fftfreq(w)[None, :] * w
    r = np.sqrt((fx * 4.0) ** 2 + fy ** 2)  # low horizontal frequency = features much wider than tall
    mask = np.exp(-((np.log(np.maximum(r, 1e-6)) - np.log(np.sqrt(lo * hi))) ** 2) / (2 * (np.log(hi / lo) / 2.2) ** 2))
    mask[0, 0] = 0
    out = np.real(np.fft.ifft2(np.fft.fft2(rng.normal(size=shape)) * mask))
    return out / (np.abs(out).max() + 1e-9)


def fbm(shape, seed):
    return noise(shape, seed, 2, 6) * 0.55 + noise(shape, seed + 1, 6, 18) * 0.3 + noise(shape, seed + 2, 18, 60) * 0.15


def ramp(el, P):
    """Sky colour by elevation (radians)."""
    e = np.degrees(el)
    stops = [(-90, P["haze"]), (-2, P["haze"]), (0, P["horizon"]), (12, P["mid"]), (55, P["zenith"]), (90, P["zenith"])]
    out = np.zeros(e.shape + (3,))
    for c in range(3):
        out[..., c] = np.interp(e, [s[0] for s in stops], [s[1][c] for s in stops])
    return out


def side_faces(P):
    y, x = np.mgrid[0:N, 0:N]
    fx = (x + 0.5) / N * 2 - 1
    fy = 1 - (y + 0.5) / N * 2
    el = np.arctan2(fy, np.sqrt(fx ** 2 + 1))
    base = ramp(el, P)
    # cloud field: periodic across the face width; rows mapped by perspective so distant
    # clouds near the horizon flatten and bunch up, like looking across a cloud deck
    rows = 768
    field = noise((rows, N), P["seed"], 1.5, 5) * 0.6 + noise((rows, N), P["seed"] + 1, 5, 16) * 0.28 + noise((rows, N), P["seed"] + 2, 16, 60) * 0.12
    e = np.degrees(el)
    # smooth, monotonic elevation -> row map (more rows near the horizon = flatter, farther clouds)
    t = np.clip((e + 1) / (P["band"] + 6), 0, 1) ** 0.75
    r = np.clip(t * (rows - 1), 0, rows - 1).astype(int)
    n = field[r, x]
    band = np.clip(1 - (e - 2) / P["band"], 0, 1) * np.clip((e + 0.5) / 2.5, 0, 1)
    dens = np.clip((n * 1.9 + (P["cover"] - 0.55) * 1.5), 0, 1)
    dens = (dens * dens * (3 - 2 * dens)) * band  # soft-edged billows
    # lit tops, shaded bases: compare with the field a little lower in the deck
    r2 = np.clip(r - 10, 0, rows - 1)
    under = np.clip((field[r2, x] - n) * 3 + 0.35, 0, 1)
    lit = np.array(P["lit"], float)
    shade = np.array(P["shade"], float)
    cloud = lit * (1 - under)[..., None] + shade * under[..., None]
    fade = np.clip(e / 14, 0, 1)[..., None]  # aerial perspective: far clouds melt into the haze
    cloud = cloud * (0.45 + 0.55 * fade) + base * (0.55 - 0.55 * fade)
    img = base * (1 - dens[..., None]) + cloud * dens[..., None]
    img += np.random.default_rng(1).normal(0, 1.2, img.shape)  # dither: no banding
    face = np.clip(img, 0, 255).astype(np.uint8)
    return [face, face, face, face]


def cap_face(P, up):
    y, x = np.mgrid[0:N, 0:N]
    fx = (x + 0.5) / N * 2 - 1
    fz = (y + 0.5) / N * 2 - 1
    el = np.arctan2(1, np.sqrt(fx ** 2 + fz ** 2)) * (1 if up else -1)
    img = ramp(el, P) + np.random.default_rng(9).normal(0, 1.2, (N, N, 3))
    return np.clip(img, 0, 255).astype(np.uint8)


def main(only=None):
    os.makedirs(OUT, exist_ok=True)
    for name, P in PRESETS.items():
        if only and name not in only:
            continue
        sides = side_faces(P)
        Image.fromarray(sides[0]).save(os.path.join(OUT, f"{name}_Side.png"), optimize=True)
        Image.fromarray(cap_face(P, True)).save(os.path.join(OUT, f"{name}_Up.png"), optimize=True)
        Image.fromarray(cap_face(P, False)).save(os.path.join(OUT, f"{name}_Dn.png"), optimize=True)
        print("wrote", name)


if __name__ == "__main__":
    main(sys.argv[1:] or None)
