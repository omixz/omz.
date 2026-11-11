"""Weapons, flashlight and environment props.

Weapons use the grip as origin with the barrel along -Z (matches src/shared/WeaponModels.luau).
Props sit on the ground at origin (y = 0 is the base).
Each asset: (cell, [(layer, fn_or_mesh, material, color)]). fn_or_mesh is either an SDF
function or a prebuilt (verts, normals, faces) tuple (used for grass blades)."""
import numpy as np

from . import sdf as S

METAL = (0.17, 0.17, 0.18)
STEEL = (0.38, 0.38, 0.4)
WOOD = (0.36, 0.23, 0.14)
DARKWOOD = (0.25, 0.16, 0.1)
RUBBER = (0.07, 0.07, 0.07)


def rx(a):
    return S.rot_matrix(a, 0, 0)


# ------------------------------------------------------------------ weapons
def revolver():
    def frame(P):
        body = S.rbox(P, (0, 0.3, -0.22), (0.085, 0.15, 0.3), 0.035)
        top = S.rbox(P, (0, 0.44, -0.6), (0.05, 0.035, 0.62), 0.02)
        hammer = S.rbox(P, (0, 0.47, 0.06), (0.03, 0.06, 0.05), 0.02, rx(0.4))
        guard = S.torus(P, (0, 0.12, -0.18), 0.1, 0.018, axis="x")
        guard = np.maximum(guard, P[:, 1] - 0.14)
        trigger = S.rbox(P, (0, 0.13, -0.15), (0.015, 0.06, 0.02), 0.01, rx(0.3))
        return S.smooth_union(0.015, body, top, hammer, guard, trigger)

    def cyl(P):
        c = S.cylinder(P, (0, 0.3, -0.05), (0, 0.3, -0.38), 0.15, 0.02)
        flutes = S.union(*[S.cylinder(P, (0.15 * np.cos(a), 0.3 + 0.15 * np.sin(a), 0.0), (0.15 * np.cos(a), 0.3 + 0.15 * np.sin(a), -0.43), 0.035) for a in np.linspace(0, 2 * np.pi, 7)[:-1]])
        return S.subtract(c, flutes, 0.01)

    def barrel(P):
        b = S.cylinder(P, (0, 0.36, -0.38), (0, 0.36, -1.25), 0.06, 0.01)
        bore = S.cylinder(P, (0, 0.36, -1.0), (0, 0.36, -1.3), 0.025)
        sight = S.rbox(P, (0, 0.43, -1.18), (0.012, 0.03, 0.03), 0.008)
        ejector = S.cylinder(P, (0, 0.27, -0.4), (0, 0.27, -0.9), 0.03, 0.008)
        return S.union(S.subtract(b, bore), sight, ejector)

    def grip(P):
        g = S.rbox(P, (0, 0.0, 0.06), (0.1, 0.27, 0.15), 0.07, rx(-0.22))
        return g + np.abs(S.perlin(P, 30)) * 0.004
    return 0.02, [("Frame", frame, "Metal", METAL), ("Cylinder", cyl, "Metal", STEEL), ("Barrel", barrel, "Metal", METAL), ("Grip", grip, "Wood", DARKWOOD)]


def long_gun(kind):
    L = {"rifle": 2.85, "carbine": 2.2, "shotgun": 2.3}[kind]
    by = {"rifle": 0.18, "carbine": 0.2, "shotgun": 0.22}[kind]
    br = {"rifle": 0.05, "carbine": 0.055, "shotgun": 0.075}[kind]

    def stock(P):
        butt = S.rbox(P, (0, -0.06, 0.78), (0.1, 0.22, 0.34), 0.06, rx(0.18))
        wrist = S.rbox(P, (0, 0.06, 0.32), (0.075, 0.1, 0.22), 0.05, rx(0.25))
        comb = S.rbox(P, (0, 0.12, 0.7), (0.085, 0.06, 0.3), 0.04)
        pad = S.rbox(P, (0, -0.05, 1.12), (0.105, 0.23, 0.03), 0.02, rx(0.18))
        d = S.smooth_union(0.06, butt, wrist, comb)
        return d + np.abs(S.perlin(P, 9)) * 0.003, pad

    def receiver(P):
        r = S.rbox(P, (0, by, -0.18), (0.075, 0.1, 0.36), 0.03)
        guard = np.maximum(S.torus(P, (0, by - 0.16, 0.0), 0.1, 0.018, axis="x"), P[:, 1] - (by - 0.12))
        trig = S.rbox(P, (0, by - 0.15, 0.03), (0.012, 0.05, 0.018), 0.008, rx(0.3))
        d = S.smooth_union(0.01, r, guard, trig)
        if kind == "rifle":
            bolt = S.union(S.cylinder(P, (0, by + 0.07, 0.05), (0, by + 0.07, -0.25), 0.035), S.capsule(P, (0, by + 0.07, 0.02), (0.15, by + 0.0, 0.05), 0.02), S.sphere(P, (0.16, by - 0.01, 0.05), 0.035))
            d = S.union(d, bolt)
        if kind == "carbine":
            lever = np.maximum(S.torus(P, (0, by - 0.22, 0.12), 0.1, 0.02, axis="x"), -(P[:, 1] - (by - 0.36)))
            d = S.union(d, lever, S.rbox(P, (0, by - 0.12, 0.02), (0.015, 0.1, 0.02), 0.01))
        return d

    def barrel(P):
        b = S.cylinder(P, (0, by + 0.04, -0.4), (0, by + 0.02, -L), br, 0.01)
        bore = S.cylinder(P, (0, by + 0.02, -L + 0.2), (0, by + 0.02, -L - 0.1), br * 0.55)
        sight = S.rbox(P, (0, by + 0.04 + br + 0.02, -L + 0.08), (0.012, 0.03, 0.03), 0.008)
        d = S.union(S.subtract(b, bore), sight)
        if kind in ("carbine", "shotgun"):
            d = S.union(d, S.cylinder(P, (0, by - br - 0.04, -0.5), (0, by - br - 0.04, -L + 0.15), br * 0.75, 0.01))
        return d

    def forend(P):
        if kind == "shotgun":
            f = S.cylinder(P, (0, by - 0.07, -0.85), (0, by - 0.07, -1.4), 0.1, 0.03)
            return f + np.maximum(np.sin(P[:, 2] * 70), 0) * 0.01
        z0, z1 = -0.45, -(L * 0.62)
        return S.rbox(P, (0, by - 0.04, (z0 + z1) / 2), (0.07, 0.07, abs(z1 - z0) / 2), 0.05)

    def scope(P):
        tube = S.cylinder(P, (0, by + 0.26, 0.15), (0, by + 0.26, -0.65), 0.05, 0.01)
        bells = S.union(S.cylinder(P, (0, by + 0.26, 0.12), (0, by + 0.26, 0.28), 0.07, 0.015), S.cylinder(P, (0, by + 0.26, -0.55), (0, by + 0.26, -0.75), 0.085, 0.015))
        turret = S.cylinder(P, (0, by + 0.26, -0.22), (0, by + 0.37, -0.22), 0.035)
        mounts = S.union(S.rbox(P, (0, by + 0.17, 0.05), (0.04, 0.05, 0.03), 0.01), S.rbox(P, (0, by + 0.17, -0.45), (0.04, 0.05, 0.03), 0.01))
        return S.union(tube, bells, turret, mounts)

    layers = [
        ("Stock", lambda P: stock(P)[0], "Wood", WOOD if kind != "shotgun" else DARKWOOD),
        ("Pad", lambda P: stock(P)[1], "Rubber", RUBBER),
        ("Receiver", receiver, "Metal", METAL),
        ("Barrel", barrel, "Metal", METAL),
        ("Forend", forend, "Wood", WOOD if kind != "shotgun" else DARKWOOD),
    ]
    if kind == "rifle":
        layers.append(("Scope", scope, "Metal", (0.1, 0.1, 0.11)))
    return 0.026, layers


def bow():
    # recurve limbs: a chain of tapered capsules along a curve in the YZ plane
    def curve(sign):
        ts = np.linspace(0, 1, 9)
        pts = []
        for t in ts:
            y = sign * (0.28 + t * 1.75)
            z = 0.1 + 0.32 * np.sin(t * np.pi * 0.85) - (0.25 * max(0, t - 0.82) / 0.18 if t > 0.82 else 0)
            pts.append(np.array([0, y, z]))
        return pts

    def limbs(P):
        d = None
        for sign in (1, -1):
            pts = curve(sign)
            for i in range(len(pts) - 1):
                r1 = 0.07 - 0.045 * i / (len(pts) - 1)
                r2 = 0.07 - 0.045 * (i + 1) / (len(pts) - 1)
                seg = S.round_cone(P, pts[i], pts[i + 1], r1, r2)
                d = seg if d is None else S.smooth_union(0.03, d, seg)
        return d

    def riser(P):
        return S.smooth_union(0.03, S.rbox(P, (0, 0, 0.0), (0.06, 0.32, 0.09), 0.04), S.rbox(P, (0, 0.18, -0.06), (0.045, 0.1, 0.06), 0.03))

    def grip(P):
        return S.rbox(P, (0, -0.03, 0.02), (0.07, 0.15, 0.1), 0.05) + np.maximum(np.sin(P[:, 1] * 120), 0) * 0.006

    def string(P):
        a, b = curve(1)[-1], curve(-1)[-1]
        return S.capsule(P, a, b, 0.012)

    def arrow(P):
        shaft = S.capsule(P, (0, 0.1, 0.25), (0, 0.1, -0.85), 0.018)
        head = S.round_cone(P, (0, 0.1, -0.85), (0, 0.1, -1.0), 0.035, 0.004)
        return S.union(shaft, head)
    return 0.024, [("Limbs", limbs, "Wood", WOOD), ("Riser", riser, "Wood", DARKWOOD), ("Grip", grip, "Leather", (0.2, 0.14, 0.1)), ("String", string, "Fabric", (0.85, 0.82, 0.74)), ("Arrow", arrow, "Wood", (0.7, 0.62, 0.5))]


def flashlight():
    def body(P):
        b = S.cylinder(P, (0, 0, 0.25), (0, 0, -0.05), 0.07, 0.015)
        knurl = np.maximum(np.sin(np.arctan2(P[:, 1], P[:, 0]) * 24), 0) * 0.006 * (P[:, 2] > 0.02) * (P[:, 2] < 0.2)
        head = S.cylinder(P, (0, 0, -0.05), (0, 0, -0.18), 0.1, 0.02)
        clip = S.rbox(P, (0, 0.09, 0.1), (0.03, 0.02, 0.1), 0.01)
        return S.union(b - knurl, head, clip)

    def lens(P):
        return S.cylinder(P, (0, 0, -0.17), (0, 0, -0.19), 0.085)
    return 0.01, [("Body", body, "Metal", (0.1, 0.1, 0.1)), ("Lens", lens, "Glass", (0.95, 0.92, 0.8))]


# ------------------------------------------------------------------ vegetation
def _blade(base, height, lean_dir, bend, width, segs=5):
    """One curved grass blade as a double-sided triangle strip."""
    pts, norms = [], []
    side = np.cross(lean_dir, [0, 1, 0])
    side = side / (np.linalg.norm(side) + 1e-9)
    for i in range(segs + 1):
        t = i / segs
        center = base + np.array([0, height * t, 0]) + lean_dir * bend * t * t * height
        w = width * (1 - t) ** 0.8
        pts += [center - side * w, center + side * w]
        n = np.cross(side, (lean_dir * bend * 2 * t + [0, 1, 0]))
        n = n / (np.linalg.norm(n) + 1e-9)
        norms += [n, n]
    faces = []
    for i in range(segs):
        a, b, c, d = 2 * i, 2 * i + 1, 2 * i + 2, 2 * i + 3
        faces += [[a, c, b], [b, c, d]]
    return np.array(pts), np.array(norms), np.array(faces)


def grass_clump(seed, count, h_min, h_max, radius, width, bend=0.35):
    rng = np.random.default_rng(seed)
    V, N, F = [], [], []
    off = 0
    for _ in range(count):
        r = radius * np.sqrt(rng.uniform())
        a = rng.uniform(0, 2 * np.pi)
        base = np.array([np.cos(a) * r, 0, np.sin(a) * r])
        lean = np.array([np.cos(a) + rng.normal(0, 0.4), 0, np.sin(a) + rng.normal(0, 0.4)])
        lean = lean / (np.linalg.norm(lean) + 1e-9)
        v, n, f = _blade(base, rng.uniform(h_min, h_max), lean, bend * rng.uniform(0.4, 1.3), width * rng.uniform(0.7, 1.2))
        # double-sided
        V += [v, v]
        N += [n, -n]
        F += [f + off, f[:, ::-1] + off + len(v)]
        off += 2 * len(v)
    return np.concatenate(V), np.concatenate(N), np.concatenate(F)


def fern(seed):
    rng = np.random.default_rng(seed)
    V, N, F = [], [], []
    off = 0
    for i in range(9):
        a = i / 9 * 2 * np.pi + rng.uniform(-0.2, 0.2)
        d = np.array([np.cos(a), 0, np.sin(a)])
        v, n, f = _blade(np.zeros(3), rng.uniform(1.4, 2.2), d, 0.9, 0.22, 8)
        V += [v, v]
        N += [n, -n]
        F += [f + off, f[:, ::-1] + off + len(v)]
        off += 2 * len(v)
    return np.concatenate(V), np.concatenate(N), np.concatenate(F)


def bush(seed):
    rng = np.random.default_rng(seed)
    blobs = [(np.array([rng.uniform(-0.9, 0.9), rng.uniform(0.6, 1.6), rng.uniform(-0.9, 0.9)]), rng.uniform(0.6, 1.0)) for _ in range(7)]

    def leaves(P):
        d = S.union(*[S.sphere(P, c, r) for c, r in blobs])
        return d - S.fbm(P, 3, 3, seed=seed) * 0.25 - np.abs(S.perlin(P, 9, seed + 1)) * 0.12
    return 0.08, [("Leaves", leaves, "LeafyGrass", (0.2, 0.26, 0.14))]


def pine(seed, height=26):
    rng = np.random.default_rng(seed)
    tiers = 7

    def trunk(P):
        t = S.round_cone(P, (0, 0, 0), (0, height * 0.95, 0), 0.75, 0.12)
        return t + np.abs(S.perlin(P * [1, 0.15, 1], 4, seed)) * 0.06

    def needles(P):
        d = None
        for i in range(tiers):
            y0 = height * (0.25 + 0.68 * i / tiers)
            rad = (1 - i / tiers) * 6.5 + 1.2
            cone = S.round_cone(P, (0, y0, 0), (0, y0 + height * 0.2, 0), rad, 0.3)
            cone = S.intersect(cone, -(P[:, 1] - y0 + 0.4))
            d = cone if d is None else S.smooth_union(0.6, d, cone)
        return d - S.fbm(P, 0.6, 3, seed=seed + 3) * 0.9 - np.abs(S.perlin(P, 1.7, seed + 4)) * 0.6
    return 0.3, [("Trunk", trunk, "Wood", (0.24, 0.18, 0.14)), ("Needles", needles, "LeafyGrass", (0.13, 0.19, 0.12))]


def dead_tree(seed, height=20):
    rng = np.random.default_rng(seed)
    branches = []
    for i in range(9):
        y = rng.uniform(height * 0.35, height * 0.9)
        a = rng.uniform(0, 2 * np.pi)
        L = rng.uniform(3, 7) * (1 - y / height * 0.5)
        tip = np.array([np.cos(a) * L, y + rng.uniform(1.5, 4), np.sin(a) * L])
        branches.append((np.array([0, y, 0]), tip, 0.35 * (1 - y / height) + 0.1))

    def wood(P):
        d = S.round_cone(P, (0, 0, 0), (0, height, 0), 0.9, 0.12)
        for a, b, r in branches:
            d = S.smooth_union(0.3, d, S.round_cone(P, a, b, r, 0.06))
        return d + np.abs(S.perlin(P * [1, 0.2, 1], 3, seed)) * 0.08
    return 0.2, [("Wood", wood, "Wood", (0.3, 0.27, 0.24))]


def rock(seed, size=3.0):
    rng = np.random.default_rng(seed)
    radii = np.array([rng.uniform(0.8, 1.2), rng.uniform(0.5, 0.8), rng.uniform(0.7, 1.1)]) * size

    def stone(P):
        d = S.ellipsoid(P, (0, radii[1] * 0.55, 0), radii)
        d = d - S.fbm(P, 0.8 / size * 3, 4, seed=seed) * size * 0.18
        # flat facets
        for i in range(5):
            n = rng.normal(size=3)
            n /= np.linalg.norm(n)
            d = np.maximum(d, P @ n - (radii.mean() * 0.78 + n[1] * radii[1] * 0.55))
        return d
    return max(0.06, size * 0.05), [("Stone", stone, "Rock", (0.42, 0.41, 0.39))]


# ------------------------------------------------------------------ wrecks & clutter
def car(kind="sedan", seed=0):
    rng = np.random.default_rng(seed)
    L, W = (9.5, 3.7) if kind == "sedan" else (10.5, 4.0)

    def shell(P):
        lower = S.rbox(P, (0, 1.35, 0), (W / 2, 0.55, L / 2), 0.35)
        if kind == "sedan":
            cabin = S.rbox(P, (0, 2.35, 0.3), (W / 2 - 0.2, 0.6, L * 0.24), 0.45)
        else:
            cabin = S.rbox(P, (0, 2.5, 0.8), (W / 2 - 0.05, 0.75, L * 0.38), 0.3)
        body = S.smooth_union(0.25, lower, cabin)
        arches = S.union(*[S.cylinder(P, (-W, 0.8, z), (W, 0.8, z), 0.95) for z in (L * 0.32, -L * 0.32)])
        dents = np.maximum(S.fbm(P, 0.6, 3, seed=seed), 0) * 0.25
        return S.subtract(body, arches, 0.1) + dents

    def glass(P):
        # window panels sitting just proud of the cabin: windscreen, rear screen, side windows
        if kind == "sedan":
            cy, ch, cz, cl, cw = 2.45, 0.32, 0.3, L * 0.22, W / 2 - 0.12
        else:
            cy, ch, cz, cl, cw = 2.75, 0.32, 0.8, L * 0.35, W / 2 + 0.02
        sides = S.union(*[S.rbox(P, (sx * cw, cy, cz + dz * cl * 0.5), (0.04, ch, cl * 0.42), 0.04) for sx in (1, -1) for dz in (1, -1)])
        front = S.rbox(P, (0, cy - 0.05, cz - cl - 0.1), (cw - 0.2, ch, 0.05), 0.04, S.rot_matrix(-0.5 if kind == "sedan" else -0.15, 0, 0))
        back = S.rbox(P, (0, cy - 0.05, cz + cl + 0.1), (cw - 0.2, ch, 0.05), 0.04, S.rot_matrix(0.45 if kind == "sedan" else 0.05, 0, 0))
        return S.union(sides, front, back)

    def wheels(P):
        d = None
        for x in (W / 2 - 0.25, -W / 2 + 0.25):
            for z in (L * 0.32, -L * 0.32):
                t = S.cylinder(P, (x - 0.25, 0.75, z), (x + 0.25, 0.75, z), 0.72, 0.15)
                d = t if d is None else S.union(d, t)
        return d

    def rust(P):
        patches = S.fbm(P, 0.5, 3, seed=seed + 9)
        return S.intersect(shell(P) - 0.02, -(patches - 0.15) * 0.4)
    return 0.12, [("Body", shell, "Metal", tuple(rng.choice([(0.32, 0.36, 0.38), (0.45, 0.24, 0.2), (0.6, 0.58, 0.52), (0.25, 0.3, 0.24)]))), ("Rust", rust, "CorrodedMetal", (0.36, 0.2, 0.12)), ("Glass", glass, "Glass", (0.12, 0.14, 0.15)), ("Tires", wheels, "Rubber", RUBBER)]


def rubble(seed):
    rng = np.random.default_rng(seed)
    chunks = [(np.array([rng.uniform(-2, 2), rng.uniform(0, 1.2), rng.uniform(-2, 2)]), rng.uniform(0.3, 0.9, 3), S.rot_matrix(*rng.uniform(0, 3, 3))) for _ in range(14)]

    def pile(P):
        d = S.union(*[S.rbox(P, c, h, 0.05, R) for c, h, R in chunks])
        mound = S.ellipsoid(P, (0, -0.4, 0), (2.8, 1.3, 2.6))
        return S.smooth_union(0.3, d, mound) - S.fbm(P, 2, 2, seed=seed) * 0.08
    return 0.08, [("Rubble", pile, "Concrete", (0.45, 0.44, 0.42))]


def barrel(seed):
    def can(P):
        c = S.cylinder(P, (0, 0, 0), (0, 2.8, 0), 0.95, 0.06)
        rings = S.union(*[S.torus(P, (0, y, 0), 0.95, 0.05) for y in (0.9, 1.9)])
        dent = np.maximum(S.fbm(P, 0.8, 2, seed=seed), 0) * 0.15
        return S.union(c, rings) + dent
    return 0.05, [("Drum", can, "CorrodedMetal", (0.3, 0.33, 0.3))]


def assets():
    out = {
        "Weapon_revolver": revolver(),
        "Weapon_rifle": long_gun("rifle"),
        "Weapon_carbine": long_gun("carbine"),
        "Weapon_shotgun": long_gun("shotgun"),
        "Weapon_bow": bow(),
        "Flashlight": flashlight(),
        "GrassShort_1": (None, [("Blades", grass_clump(1, 40, 0.6, 1.3, 0.8, 0.05), "Grass", (0.35, 0.42, 0.2))]),
        "GrassShort_2": (None, [("Blades", grass_clump(2, 34, 0.5, 1.1, 0.7, 0.055), "Grass", (0.42, 0.44, 0.22))]),
        "GrassTall_1": (None, [("Blades", grass_clump(3, 46, 2.6, 4.6, 1.0, 0.07, 0.25), "Grass", (0.44, 0.45, 0.26))]),
        "GrassTall_2": (None, [("Blades", grass_clump(4, 40, 3.0, 5.2, 1.2, 0.075, 0.2), "Grass", (0.5, 0.48, 0.3))]),
        "GrassTall_3": (None, [("Blades", grass_clump(5, 52, 2.2, 4.0, 1.1, 0.065, 0.3), "Grass", (0.38, 0.42, 0.22))]),
        "Fern_1": (None, [("Fronds", fern(6), "Grass", (0.2, 0.32, 0.14))]),
        "Bush_1": bush(7),
        "Bush_2": bush(8),
        "Pine_1": pine(9),
        "Pine_2": pine(10, 32),
        "DeadTree_1": dead_tree(11),
        "Rock_1": rock(12, 2.2),
        "Rock_2": rock(13, 3.5),
        "Boulder_1": rock(14, 7.0),
        "CarSedan_1": car("sedan", 15),
        "CarSedan_2": car("sedan", 16),
        "CarVan_1": car("van", 17),
        "Rubble_1": rubble(18),
        "Barrel_1": barrel(19),
    }
    return out
