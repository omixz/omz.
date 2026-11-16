"""The Hushed: gaunt human anatomy taken by the Pall: charred skin, lumpy salt crust,
spines, rags, a hollow maw. Exported in the "enemy" skeleton format used by EnemyService."""
import numpy as np

from . import human as H
from . import sdf as S

CRUST = (0.9, 0.88, 0.83)


def S_and(f, g):
    return lambda P: np.maximum(f(P), g(P))
MAW = (0.03, 0.025, 0.025)


def crust_field(P, centers, radius, seed):
    """Lumpy salt growths around a set of centres."""
    d = S.union(*[S.sphere(P, c, r) for c, r in centers])
    return d - S.fbm(P, 9, 3, seed=seed) * radius * 0.35 - np.abs(S.perlin(P, 22, seed + 1)) * 0.02


def encrust(base, coverage, thickness, seed, bias_up=0.0):
    """Salt crust growing as a jagged layer over a body SDF, only in patches."""
    def fn(P):
        patch = S.fbm(P, 2.4, 3, seed=seed) + (coverage - 0.5) * 1.2 + bias_up * (P[:, 1] - 4.2) * 0.4
        grow = thickness * (0.45 + 0.55 * np.clip(patch * 2, 0, 1))
        jag = np.abs(S.perlin(P, 11, seed + 2)) * 0.02
        cracks = np.exp(-(S.perlin(P, 7, seed + 6) ** 2) * 700) * 0.025
        d = base(P) - grow - jag + cracks
        return S.intersect(d, -patch * 0.25, 0.02)
    return fn


def skin_detail(base, seed):
    """Taut, veined, wrinkled skin over a body SDF (raised veins + fine wrinkles)."""
    def fn(P):
        veins = np.exp(-(S.perlin(P, 4.5, seed) ** 2) * 260) * 0.012
        wrinkles = S.fbm(P, 16, 2, seed=seed + 1) * 0.007
        return base(P) - veins + wrinkles
    return fn


def _frame(n, rng):
    """World-from-local rotation whose local Y points along n (with a random twist)."""
    y = n / np.linalg.norm(n)
    a = rng.normal(size=3)
    x = np.cross(y, a)
    x /= np.linalg.norm(x)
    z = np.cross(x, y)
    return np.stack([x, y, z], axis=1)


def crystal_cluster(rng, anchor, outward, count, size, spread=0.12):
    """Halite-like salt crystals: blocky, square-sectioned prisms bursting out of the body."""
    out = []
    outward = np.asarray(outward, float)
    outward /= np.linalg.norm(outward)
    for _ in range(count):
        n = outward + rng.normal(scale=0.45, size=3)
        n /= np.linalg.norm(n)
        sz = size * rng.uniform(0.55, 1.15)
        length = sz * rng.uniform(1.4, 3.2)
        base = np.asarray(anchor, float) + rng.normal(scale=spread, size=3)
        c = base + n * length * 0.55
        out.append((c, np.array([sz * 0.5, length * 0.5, sz * 0.5]), _frame(n, rng)))
    return out


def crystal_mesh(specs):
    """Exact faceted geometry: square prisms with a pyramid tip (flat-shaded, sharp edges)."""
    V, N, F = [], [], []

    def tri(a, b, c):
        n = np.cross(b - a, c - a)
        n = n / max(np.linalg.norm(n), 1e-9)
        if np.dot(n, (a + b + c) / 3 - centre) < 0:  # keep every face pointing outward
            b, c = c, b
            n = -n
        base = len(V)
        V.extend([a, b, c])
        N.extend([n, n, n])
        F.extend([base, base + 1, base + 2])

    for c, half, rot in specs:
        centre = c
        hx, hy, hz = half
        tip = hy * 0.35
        loc = [np.array(p) for p in (
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
            (-hx, hy - tip, -hz), (hx, hy - tip, -hz), (hx, hy - tip, hz), (-hx, hy - tip, hz),
            (0, hy + tip * 0.2, 0))]
        w = [c + rot @ p for p in loc]
        b0, b1, b2, b3, t0, t1, t2, t3, apex = w
        for q in ((b0, b1, t1, t0), (b1, b2, t2, t1), (b2, b3, t3, t2), (b3, b0, t0, t3)):
            tri(q[0], q[2], q[1])
            tri(q[0], q[3], q[2])
        tri(b0, b2, b1)
        tri(b0, b3, b2)
        for a_, b_ in ((t0, t1), (t1, t2), (t2, t3), (t3, t0)):
            tri(a_, apex, b_)
    if not V:
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros(0, int)
    return np.array(V, float), np.array(N, float), np.array(F, int).reshape(-1, 3)


def crystals(specs):
    return crystal_mesh(specs)


def tatters(base, coverage, seed, thickness=0.022):
    """Rotten cloth: partial, holed, hanging strips."""
    def fn(P):
        holes = S.fbm(P, 5, 3, seed=seed) + (coverage - 0.5) * 1.4
        d = base(P) - thickness + S.folds(P, (0, 1, 0), 3, 0.02, seed)
        return S.intersect(d, -holes * 0.3, 0.01)
    return fn


def build_segments(kind="Drifter", rng_seed=1):
    rng = np.random.default_rng(rng_seed)
    params = {
        "Drifter": dict(b=0.82, arms=1.15, crust=0.5, spines=3, maw=True, sealed=False, rags=(0.27, 0.25, 0.22), skin=(0.2, 0.18, 0.17), hunch=0.0),
        "Rusher": dict(b=0.78, arms=1.1, crust=0.25, spines=1, maw=True, sealed=False, rags=(0.3, 0.26, 0.22), skin=(0.31, 0.25, 0.22), hunch=0.0, halfFace=True),
        "Seeker": dict(b=0.8, arms=1.22, crust=0.85, spines=6, maw=False, sealed=True, rags=(0.22, 0.21, 0.2), skin=(0.17, 0.16, 0.15), hunch=0.0),
        "Bellwether": dict(b=0.85, arms=1.12, crust=0.6, spines=4, maw=True, sealed=False, rags=(0.24, 0.24, 0.25), skin=(0.22, 0.22, 0.23), hunch=0.0, disc=True),
        "Tidewalker": dict(b=1.4, arms=1.25, crust=1.0, spines=12, maw=True, sealed=False, rags=None, skin=(0.15, 0.14, 0.13), hunch=0.0, bulk=True),
    }[kind]
    b = params["b"]
    J = H.joints(b, 0.0, 1.0)
    bulk = 1.25 if params.get("bulk") else 1.0
    lb = max(b, 0.96) * bulk  # limb thickness: gaunt torso, but sinewy (not stick) limbs
    sd = lambda fn, k: skin_detail(fn, 40 + k)
    # stretch the arms (longer, ape-like reach)
    for s in "RL":
        sx = 1 if s == "R" else -1
        # shoulders sit on the edge of the chest, whatever the build (gaunt or hulking)
        chest = 0.66 * b * (1.25 if params.get("bulk") else 1.0)
        shift = abs(J[s + "shoulder"][0]) - (chest + 0.12)
        for key in ("shoulder", "elbow", "wrist", "handEnd"):
            J[s + key] = J[s + key] - [sx * shift, 0, 0]
        if params.get("bulk"):
            for key in ("hip", "knee", "ankle", "toe", "ground"):
                J[s + key] = J[s + key] * [1.75, 1, 1]  # a wide, braced stance under the weight
        sh = J[s + "shoulder"]
        for key in ("elbow", "wrist", "handEnd"):
            J[s + key] = sh + (J[s + key] - sh) * params["arms"]
        J[s + "ground"] = np.array([J[s + "ankle"][0], 0.0, 0.0])
    skin = params["skin"]
    seg = {}

    # salt-crust centres (shoulders, spine, head)
    centers_torso = []
    for i in range(int(4 + 10 * params["crust"])):
        side = rng.choice([-1, 1])
        y = rng.uniform(3.9, 4.9)
        x = side * rng.uniform(0.1, 0.65) * b
        z = rng.uniform(0.15, 0.4) * b
        centers_torso.append((np.array([x, y, z]), rng.uniform(0.08, 0.2) * (1 + params["crust"] * 0.5)))
    for s in "RL":
        centers_torso.append((J[s + "shoulder"] + [0, 0.12, 0.05], 0.16 + 0.12 * params["crust"]))

    hc = J["head"]

    def head_skin(P):
        d = H.skin_head(P, J, b, 0.0, face=not params["sealed"])
        if params["maw"]:
            # the face has fallen in: a hollow, ragged maw from nose to chin
            maw = S.ellipsoid(P, hc + [0, -0.22, -0.38], [0.17, 0.3, 0.22]) + S.fbm(P, 14, 2, seed=5) * 0.03
            d = S.subtract(d, maw, 0.03)
        if params.get("disc"):
            d = S.smooth_union(0.08, d, S.ellipsoid(P, hc + [0, 0.15, 0.05], [0.62, 0.22, 0.6]))
        return d

    head = [("Skin", sd(head_skin, 0), "SmoothPlastic", skin)]
    if params["maw"]:
        head.append(("Maw", lambda P: S.intersect(S.ellipsoid(P, hc + [0, -0.22, -0.3], [0.15, 0.28, 0.17]), H.skin_head(P, J, b, 0.0, face=False) + 0.02), "SmoothPlastic", MAW))
    if params["sealed"]:
        def shell_head(P):
            mass = S.smooth_union(0.12, S.ellipsoid(P, hc + [0, 0.1, 0.02], [0.47, 0.6, 0.5]), S.ellipsoid(P, hc + [0.12, 0.38, 0.1], [0.3, 0.3, 0.32]), S.ellipsoid(P, hc + [-0.18, 0.22, -0.16], [0.26, 0.28, 0.28]))
            mass = mass - S.fbm(P, 4, 3, seed=8) * 0.09
            cracks = np.exp(-(S.perlin(P, 9, seed=13) ** 2) * 900) * 0.03
            return mass + cracks - np.abs(S.perlin(P, 26, seed=14)) * 0.015
        head.append(("Crust", shell_head, "Sand", CRUST))
    elif params.get("halfFace"):
        head.append(("Crust", lambda P: S.intersect(encrust(lambda Q: H.skin_head(Q, J, b, 0.0, face=False), 0.9, 0.05, 9)(P), -(P[:, 0] - hc[0]) * -1 + 0.02), "Sand", CRUST))
    else:
        crusted = encrust(lambda Q: H.skin_head(Q, J, b, 0.0, face=False), 0.15 + params["crust"] * 0.25, 0.045, 10)
        head.append(("Crust", lambda P: np.maximum(crusted(P), -(P[:, 2] - (hc[2] - 0.05))), "Sand", CRUST))  # keep the face clear
    # salt crystals: the Pall grows out of them as blocky halite, heavier on one side
    w = J["waist"]
    side = 1 if rng.random() < 0.5 else -1
    k = params["crust"]
    xtals = {"Head": [], "Torso": [], "UpperArm": [], "LowerArm": []}
    if params["sealed"]:
        for i in range(9):
            a = np.array([rng.uniform(-0.25, 0.25), rng.uniform(0.0, 0.45), rng.uniform(-0.3, 0.2)])
            xtals["Head"] += crystal_cluster(rng, hc + a, a + [0, 0.3, 0], 3, 0.22, 0.05)
    else:
        n = int(1 + 4 * k)
        xtals["Head"] += crystal_cluster(rng, hc + [side * 0.3, 0.18, 0.08], [side, 0.8, 0.3], n, 0.12 + 0.08 * k, 0.06)
    xtals["Torso"] += crystal_cluster(rng, J[("R" if side > 0 else "L") + "shoulder"] + [0, 0.14, 0.05], [side * 0.5, 1, 0.4], int(3 + 8 * k), 0.13 + 0.1 * k, 0.1)
    xtals["Torso"] += crystal_cluster(rng, w + [-side * 0.15, 0.9, 0.3 * b], [0, 0.4, 1], int(2 + 7 * k), 0.1 + 0.08 * k, 0.16)
    if k >= 0.5:
        xtals["Torso"] += crystal_cluster(rng, w + [side * 0.3, 0.3, 0.25 * b], [side * 0.6, 0.2, 1], int(5 * k), 0.09, 0.12)
    xtals["UpperArm"] += crystal_cluster(rng, (J[("R" if side > 0 else "L") + "shoulder"] + J[("R" if side > 0 else "L") + "elbow"]) / 2, [side, 0, 0.5], int(1 + 4 * k), 0.08 + 0.05 * k, 0.08)
    xtals["LowerArm"] += crystal_cluster(rng, (J[("R" if side > 0 else "L") + "elbow"] * 0.6 + J[("R" if side > 0 else "L") + "wrist"] * 0.4), [side, 0, 0.6], int(3 * k), 0.07, 0.06)
    if xtals["Head"]:
        head.append(("Crystals", crystals(xtals["Head"]), "Salt", CRUST))
    seg["Head"] = head

    w = J["waist"]

    def torso_skin(P):
        d = H.skin_chest(P, J, b * bulk, 0.0)
        # ribs showing through (gaunt) - subtle grooves
        band = (P[:, 1] > w[1] + 0.15) & (P[:, 1] < w[1] + 0.95)
        curve = (P[:, 1] - w[1]) * 15 + np.abs(P[:, 0]) * 6  # ribs sweep down toward the sides
        ribs = (np.abs(np.sin(curve)) ** 3) * 0.032 * band * (1.0 - 0.6 * (b > 1.1))
        return d + ribs

    torso = [("Skin", sd(torso_skin, 1), "SmoothPlastic", skin)]
    torso.append(("Crust", encrust(lambda Q: H.skin_chest(Q, J, b * bulk, 0.0), 0.12 + params["crust"] * 0.38, 0.05 + 0.08 * params["crust"], 3, 0.5), "Sand", CRUST))
    spines = []
    for i in range(params["spines"] // 2):
        base = np.array([rng.uniform(-0.45, 0.45) * b, rng.uniform(4.0, 4.9), 0.32 * b * bulk])
        tip = base + [rng.uniform(-0.2, 0.2), rng.uniform(0.1, 0.45), rng.uniform(0.3, 0.75)]
        spines.append((base, tip, rng.uniform(0.06, 0.1)))
    torso.append(("Crystals", crystals(xtals["Torso"]), "Salt", CRUST))
    if spines:
        torso.append(("Spines", lambda P: S.union(*[S.round_cone(P, a, t, r, 0.012) for a, t, r in spines]), "Sand", CRUST))
    if params["rags"]:
        torso.append(("Rags", S_and(tatters(lambda Q: H.skin_chest(Q, J, b, 0.0), 0.5, 31), lambda P: H.below(P, w[1] + 0.95)), "Fabric", params["rags"]))
    seg["Torso"] = torso

    seg["Pelvis"] = [("Skin", sd(lambda P: H.skin_pelvis(P, J, b * bulk, 0.0), 2), "SmoothPlastic", skin)]
    if params["rags"]:
        seg["Pelvis"].append(("Rags", tatters(lambda Q: H.skin_pelvis(Q, J, b, 0.0), 0.75, 35, 0.045), "Fabric", params["rags"]))

    for s, name in (("R", "Right"), ("L", "Left")):
        seg[name + "UpperArm"] = [("Skin", sd((lambda s=s: lambda P: H.skin_upper_arm(P, J, s, lb))(), 3), "SmoothPlastic", skin)]
        if params["crust"] > 0.4:
            seg[name + "UpperArm"].append(("Crust", (lambda s=s: encrust(lambda Q: H.skin_upper_arm(Q, J, s, lb), params["crust"] * 0.55, 0.05, 12 + (s == "L"), 0.4))(), "Sand", CRUST))

        arm_side = "Right" if side > 0 else "Left"
        if name == arm_side and xtals["UpperArm"]:
            seg[name + "UpperArm"].append(("Crystals", crystals(xtals["UpperArm"]), "Salt", CRUST))

        def lower(P, s=s):
            arm = H.skin_lower_arm(P, J, s, lb)
            hand = H.skin_hand(P, J, s, lb)
            sx = 1 if s == "R" else -1
            tips = [J[s + "wrist"] + [-sx * 0.12, -0.42, z] for z in (-0.08, -0.027, 0.027, 0.078)]  # curled fingertips
            claws = S.union(*[S.round_cone(P, t + [sx * 0.01, 0.02, 0], t + [-sx * 0.07, -0.07, 0], 0.022, 0.006) for t in tips])
            return S.smooth_union(0.04, arm, hand, claws)
        seg[name + "LowerArm"] = [("Skin", sd(lower, 4), "SmoothPlastic", skin)]
        if name == arm_side and xtals["LowerArm"]:
            seg[name + "LowerArm"].append(("Crystals", crystals(xtals["LowerArm"]), "Salt", CRUST))
        seg[name + "UpperLeg"] = [("Skin", sd((lambda s=s: lambda P: H.skin_upper_leg(P, J, s, lb))(), 5), "SmoothPlastic", skin)]
        if params["rags"]:
            seg[name + "UpperLeg"].append(("Rags", (lambda s=s: S_and(tatters(lambda Q: H.skin_upper_leg(Q, J, s, b), 0.65, 37 + (s == "L")), lambda P: H.above(P, J[s + "knee"][1] - 0.15)))(), "Fabric", params["rags"]))

        def lowerleg(P, s=s):
            leg = H.skin_lower_leg(P, J, s, lb)
            foot = H.skin_foot(P, J, s, lb)
            return S.smooth_union(0.05, leg, foot)
        seg[name + "LowerLeg"] = [("Skin", sd(lowerleg, 6), "SmoothPlastic", skin)]
    return seg, J


ENEMY_ANCHORS = {
    "Pelvis": ("root", None),
    "Torso": ("waist", "neck"),
    "Head": ("neck", None),
}
for _s, _n in (("R", "Right"), ("L", "Left")):
    ENEMY_ANCHORS[_n + "UpperArm"] = (_s + "shoulder", _s + "elbow")
    ENEMY_ANCHORS[_n + "LowerArm"] = (_s + "elbow", _s + "handEnd")
    ENEMY_ANCHORS[_n + "UpperLeg"] = (_s + "hip", _s + "knee")
    ENEMY_ANCHORS[_n + "LowerLeg"] = (_s + "knee", _s + "ground")


def enemy_bounds(seg, J):
    m = {
        "Pelvis": "LowerTorso", "Torso": "UpperTorso", "Head": "Head",
        "RightUpperArm": "RUpperArm", "LeftUpperArm": "LUpperArm",
        "RightLowerArm": "RLowerArm", "LeftLowerArm": "LLowerArm",
        "RightUpperLeg": "RUpperLeg", "LeftUpperLeg": "LUpperLeg",
        "RightLowerLeg": "RLowerLeg", "LeftLowerLeg": "LLowerLeg",
    }
    lo, hi = H.segment_bounds(m[seg], J)
    if "LowerArm" in seg:
        s = "R" if seg.startswith("Right") else "L"
        lo = np.minimum(lo, J[s + "handEnd"] - 0.35)
        hi = np.maximum(hi, J[s + "handEnd"] + 0.35)
    if "LowerLeg" in seg:
        s = "R" if seg.startswith("Right") else "L"
        lo = np.minimum(lo, J[s + "toe"] - 0.35)
        lo[1] = -0.2
    return lo, hi


def human_to_enemy(segs):
    """Convert human r15-format segments (R/L prefixed short names) to enemy format."""
    out = {"Head": segs["Head"], "Torso": segs["UpperTorso"], "Pelvis": segs["LowerTorso"]}
    for s, n in (("R", "Right"), ("L", "Left")):
        out[n + "UpperArm"] = segs[s + "UpperArm"]
        out[n + "UpperLeg"] = segs[s + "UpperLeg"]
        out[n + "LowerArm"] = _merge(segs[s + "LowerArm"], segs[s + "Hand"])
        out[n + "LowerLeg"] = _merge(segs[s + "LowerLeg"], segs[s + "Foot"])
    return out


def _merge(a, b):
    layers = {}
    order = []
    for name, fn, mat, col in a + b:
        key = (name, mat)
        if key in layers:
            prev = layers[key]
            layers[key] = (name, (lambda f1, f2: lambda P: np.minimum(f1(P), f2(P)))(prev[1], fn), mat, prev[3])
        else:
            layers[key] = (name, fn, mat, col)
            order.append(key)
    return [layers[k] for k in order]
