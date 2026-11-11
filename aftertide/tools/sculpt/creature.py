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


def tatters(base, coverage, seed, thickness=0.035):
    """Rotten cloth: partial, holed, hanging strips."""
    def fn(P):
        holes = S.fbm(P, 5, 3, seed=seed) + (coverage - 0.5) * 1.4
        d = base(P) - thickness + S.folds(P, (0, 1, 0), 3, 0.02, seed)
        return S.intersect(d, -holes * 0.3, 0.01)
    return fn


def build_segments(kind="Drifter", rng_seed=1):
    rng = np.random.default_rng(rng_seed)
    params = {
        "Drifter": dict(b=0.82, arms=1.08, crust=0.5, spines=3, maw=True, sealed=False, rags=(0.27, 0.25, 0.22), skin=(0.2, 0.18, 0.17), hunch=0.0),
        "Rusher": dict(b=0.78, arms=1.1, crust=0.25, spines=1, maw=True, sealed=False, rags=(0.3, 0.26, 0.22), skin=(0.31, 0.25, 0.22), hunch=0.0, halfFace=True),
        "Seeker": dict(b=0.8, arms=1.22, crust=0.85, spines=6, maw=False, sealed=True, rags=(0.22, 0.21, 0.2), skin=(0.17, 0.16, 0.15), hunch=0.0),
        "Bellwether": dict(b=0.85, arms=1.12, crust=0.6, spines=4, maw=True, sealed=False, rags=(0.24, 0.24, 0.25), skin=(0.22, 0.22, 0.23), hunch=0.0, disc=True),
        "Tidewalker": dict(b=1.4, arms=1.25, crust=1.0, spines=12, maw=True, sealed=False, rags=None, skin=(0.15, 0.14, 0.13), hunch=0.0, bulk=True),
    }[kind]
    b = params["b"]
    J = H.joints(b, 0.0, 1.0)
    # stretch the arms (longer, ape-like reach)
    for s in "RL":
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
            maw = S.ellipsoid(P, hc + [0, -0.17, -0.38], [0.17, 0.22, 0.2]) + S.fbm(P, 14, 2, seed=5) * 0.03
            d = S.subtract(d, maw, 0.03)
        if params.get("disc"):
            d = S.smooth_union(0.08, d, S.ellipsoid(P, hc + [0, 0.15, 0.05], [0.62, 0.22, 0.6]))
        return d

    head = [("Skin", head_skin, "SmoothPlastic", skin)]
    if params["maw"]:
        head.append(("Maw", lambda P: S.intersect(S.ellipsoid(P, hc + [0, -0.17, -0.3], [0.15, 0.2, 0.16]), H.skin_head(P, J, b, 0.0, face=False) + 0.02), "SmoothPlastic", MAW))
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
    seg["Head"] = head

    w = J["waist"]
    bulk = 1.25 if params.get("bulk") else 1.0

    def torso_skin(P):
        d = H.skin_chest(P, J, b * bulk, 0.0)
        # ribs showing through (gaunt) - subtle grooves
        ribs = np.abs(np.sin((P[:, 1] - w[1]) * 18)) * 0.012 * (P[:, 1] > w[1] + 0.2) * (P[:, 1] < w[1] + 0.9)
        return d + ribs

    torso = [("Skin", torso_skin, "SmoothPlastic", skin)]
    torso.append(("Crust", encrust(lambda Q: H.skin_chest(Q, J, b * bulk, 0.0), 0.12 + params["crust"] * 0.38, 0.05 + 0.08 * params["crust"], 3, 0.5), "Sand", CRUST))
    spines = []
    for i in range(params["spines"]):
        base = np.array([rng.uniform(-0.45, 0.45) * b, rng.uniform(4.0, 4.9), 0.32 * b * bulk])
        tip = base + [rng.uniform(-0.2, 0.2), rng.uniform(0.1, 0.45), rng.uniform(0.3, 0.75)]
        spines.append((base, tip, rng.uniform(0.06, 0.1)))
    if spines:
        torso.append(("Spines", lambda P: S.union(*[S.round_cone(P, a, t, r, 0.012) for a, t, r in spines]), "Sand", CRUST))
    if params["rags"]:
        torso.append(("Rags", S_and(tatters(lambda Q: H.skin_chest(Q, J, b, 0.0), 0.5, 31), lambda P: H.below(P, w[1] + 0.95)), "Fabric", params["rags"]))
    seg["Torso"] = torso

    seg["Pelvis"] = [("Skin", lambda P: H.skin_pelvis(P, J, b * bulk, 0.0), "SmoothPlastic", skin)]
    if params["rags"]:
        seg["Pelvis"].append(("Rags", tatters(lambda Q: H.skin_pelvis(Q, J, b, 0.0), 0.75, 35, 0.045), "Fabric", params["rags"]))

    for s, name in (("R", "Right"), ("L", "Left")):
        seg[name + "UpperArm"] = [("Skin", (lambda s=s: lambda P: H.skin_upper_arm(P, J, s, b * bulk))(), "SmoothPlastic", skin)]
        if params["crust"] > 0.4:
            seg[name + "UpperArm"].append(("Crust", (lambda s=s: encrust(lambda Q: H.skin_upper_arm(Q, J, s, b * bulk), params["crust"] * 0.55, 0.05, 12 + (s == "L"), 0.4))(), "Sand", CRUST))

        def lower(P, s=s):
            arm = H.skin_lower_arm(P, J, s, b * bulk)
            hand = H.skin_hand(P, J, s, b * bulk)
            claws = S.union(*[S.round_cone(P, J[s + "handEnd"] + [0, 0.06, -0.09 + i * 0.06], J[s + "handEnd"] + [0, -0.12, -0.12 + i * 0.06], 0.025, 0.008) for i in range(4)])
            return S.smooth_union(0.04, arm, hand, claws)
        seg[name + "LowerArm"] = [("Skin", lower, "SmoothPlastic", skin)]
        seg[name + "UpperLeg"] = [("Skin", (lambda s=s: lambda P: H.skin_upper_leg(P, J, s, b * bulk))(), "SmoothPlastic", skin)]
        if params["rags"]:
            seg[name + "UpperLeg"].append(("Rags", (lambda s=s: S_and(tatters(lambda Q: H.skin_upper_leg(Q, J, s, b), 0.65, 37 + (s == "L")), lambda P: H.above(P, J[s + "knee"][1] - 0.15)))(), "Fabric", params["rags"]))

        def lowerleg(P, s=s):
            leg = H.skin_lower_leg(P, J, s, b * bulk)
            foot = H.skin_foot(P, J, s, b * bulk)
            return S.smooth_union(0.05, leg, foot)
        seg[name + "LowerLeg"] = [("Skin", lowerleg, "SmoothPlastic", skin)]
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
