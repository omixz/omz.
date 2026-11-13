"""Procedural, seamlessly tiling surface detail (normal + roughness maps) for the sculpted
meshes: fabric weave, twill, leather grain, skin, salt crystal, metal, wood, rock, bark.
No colour map on purpose: colour stays the MeshPart's Color, so outfits can recolour it.
Everything is periodic (FFT noise, wrapped Voronoi) so the maps tile without seams."""
import io

import numpy as np
from PIL import Image

N = 512


def _noise(seed, lo, hi, size=N):
    """Band-limited periodic noise: white noise filtered to frequencies lo..hi (cycles/tile)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(size) * size
    fx, fy = np.meshgrid(f, f)
    r = np.sqrt(fx ** 2 + fy ** 2)
    mask = np.exp(-((np.log(np.maximum(r, 1e-6)) - np.log(np.sqrt(lo * hi))) ** 2) / (2 * (np.log(hi / lo) / 2.5) ** 2))
    mask[0, 0] = 0
    spec = np.fft.fft2(rng.normal(size=(size, size))) * mask
    out = np.real(np.fft.ifft2(spec))
    return out / (np.abs(out).max() + 1e-9)


def _voronoi(seed, cells, size=N):
    """Wrapped Voronoi: (F1 distance, F2-F1 edge distance, cell id), periodic."""
    rng = np.random.default_rng(seed)
    pts = rng.random((cells, 2))
    y, x = np.mgrid[0:size, 0:size] / size
    d1 = np.full((size, size), 9.0)
    d2 = np.full((size, size), 9.0)
    cid = np.zeros((size, size), int)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(x - px)
        dy = np.abs(y - py)
        dx = np.minimum(dx, 1 - dx)
        dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < d1
        d2 = np.where(closer, d1, np.minimum(d2, d))
        cid = np.where(closer, i, cid)
        d1 = np.where(closer, d, d1)
    return d1 * np.sqrt(cells), (d2 - d1) * np.sqrt(cells), cid


def _grid(size=N):
    y, x = np.mgrid[0:size, 0:size] / size
    return x, y


def height(kind):
    x, y = _grid()
    tau = 2 * np.pi
    if kind == "fabric":  # plain weave: over-under threads + slub irregularity
        t = 96
        warp = np.sin(x * tau * t) * 0.5 + 0.5
        weft = np.sin(y * tau * t) * 0.5 + 0.5
        checker = np.sign(np.sin(x * tau * t / 2) * np.sin(y * tau * t / 2))
        h = np.where(checker > 0, warp * 0.7 + weft * 0.3, weft * 0.7 + warp * 0.3)
        return h * 0.6 + _noise(1, 6, 40) * 0.25 + _noise(2, 60, 200) * 0.15
    if kind == "twill":  # diagonal twill (trousers, canvas)
        t = 110
        h = np.sin((x + y) * tau * t) * 0.5 + 0.5
        h = h * (0.75 + 0.25 * (np.sin(y * tau * t * 2) * 0.5 + 0.5))
        return h * 0.6 + _noise(3, 4, 30) * 0.3 + _noise(4, 80, 220) * 0.1
    if kind == "leather":  # pebbled grain with creases
        _, edge, _ = _voronoi(5, 260, N // 4)  # small tile, repeated: fine pebbles, cheap
        grain = np.tile(np.clip(edge * 3, 0, 1), (4, 4))
        return grain * 0.55 + _noise(6, 3, 12) * 0.3 + _noise(7, 40, 160) * 0.15
    if kind == "skin":  # pores + soft creases
        _, edge, _ = _voronoi(8, 2500)
        pores = -np.exp(-(edge * 12) ** 2) * 0.25
        return pores + _noise(9, 2, 10) * 0.35 + _noise(10, 30, 120) * 0.2
    if kind == "salt":  # crystalline facets: flat plates with sharp breaks
        f1, edge, cid = _voronoi(11, 140)
        tilt = np.random.default_rng(12).normal(size=(140, 2))
        plates = (x * tilt[cid, 0] + y * tilt[cid, 1]) * 2.0
        plates = plates - np.floor(plates)
        return plates * 0.5 + np.clip(edge * 4, 0, 1) * 0.4 + _noise(13, 50, 200) * 0.1
    if kind == "metal":  # brushed + a few scratches and pits
        brushed = _noise(14, 1, 3, N)[:, :1].repeat(N, 1) * 0.0 + np.sin(y * tau * 300 + _noise(15, 2, 8) * 3) * 0.15
        scratches = np.clip(np.abs(_noise(16, 20, 60)) - 0.85, 0, 1) * 3
        return brushed + scratches * 0.5 + _noise(17, 4, 20) * 0.2
    if kind == "wood":  # grain lines along Y with knots
        warp = _noise(18, 1, 4) * 0.025
        rings = np.sin((x + warp) * tau * 40) * 0.5 + 0.5
        return rings * 0.6 + _noise(19, 30, 150) * 0.25 + _noise(20, 2, 6) * 0.15
    if kind == "rock":
        _, edge, _ = _voronoi(21, 60)
        return _noise(22, 2, 16) * 0.5 + np.clip(edge * 2, 0, 1) * 0.3 + _noise(23, 40, 200) * 0.2
    if kind == "bark":  # vertical furrows
        warp = _noise(24, 2, 8) * 0.05
        furrows = np.abs(np.sin((x + warp) * tau * 14)) ** 0.5
        return furrows * 0.7 + _noise(25, 8, 60) * 0.3
    raise ValueError(kind)


STRENGTH = {"fabric": 2.2, "twill": 2.0, "leather": 2.6, "skin": 1.2, "salt": 4.0, "metal": 1.5, "wood": 2.2, "rock": 4.0, "bark": 5.0}
ROUGH = {"fabric": (0.85, 0.08), "twill": (0.82, 0.08), "leather": (0.55, 0.15), "skin": (0.5, 0.12), "salt": (0.35, 0.25), "metal": (0.38, 0.2), "wood": (0.7, 0.12), "rock": (0.85, 0.1), "bark": (0.9, 0.06)}
METAL = {"metal": 0.9}


def normal_png(kind):
    h = height(kind)
    h = (h - h.min()) / (np.ptp(h) + 1e-9)
    s = STRENGTH[kind]
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * s
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * s
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    img = ((n * 0.5 + 0.5) * 255).astype(np.uint8)
    return _png(img)


def mr_png(kind):
    """glTF metallicRoughness: G = roughness, B = metalness."""
    base, var = ROUGH[kind]
    rough = np.clip(base + _noise(30 + len(kind), 3, 24) * var, 0.05, 1)
    metal = np.full_like(rough, METAL.get(kind, 0.0))
    img = np.stack([np.zeros_like(rough), rough, metal], -1)
    return _png((img * 255).astype(np.uint8))


def _png(arr):
    buf = io.BytesIO()
    Image.fromarray(arr, "RGB").save(buf, "PNG", optimize=True)
    return buf.getvalue()


# Roblox material name of a layer -> surface kind (None = keep it smooth)
BY_MATERIAL = {
    "Fabric": "fabric", "Leather": "leather", "SmoothPlastic": "skin", "Salt": "salt", "Sand": "salt",
    "Metal": "metal", "CorrodedMetal": "metal", "DiamondPlate": "metal", "Wood": "wood", "WoodPlanks": "wood",
    "Rock": "rock", "Slate": "rock", "Concrete": "rock", "Rubber": "leather", "Plastic": None, "Glass": None,
    "LeafyGrass": None, "Grass": None, "Neon": None,
}


def kind_for(material, layer_name=""):
    if material == "Fabric" and layer_name in ("Pants",):
        return "twill"
    if layer_name in ("Trunk", "Bark", "Log"):
        return "bark"
    if material == "SmoothPlastic" and layer_name not in ("Skin",):
        return None  # eyes, irises, maws, paint stay smooth
    return BY_MATERIAL.get(material)
