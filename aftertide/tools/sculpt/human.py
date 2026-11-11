"""Human sculptor: anatomy + clothing layers, split into rigid segments that ride a skeleton.

Every segment is a set of layers (skin, jacket, trousers, boots, gear...). Each layer is an
SDF built only from the primitives belonging to that segment, with overlapping ball joints so
nothing gaps when limbs rotate. Two export formats:
  * "r15"   : Head, UpperTorso, LowerTorso, {L,R}{UpperArm,LowerArm,Hand,UpperLeg,LowerLeg,Foot}
  * "enemy" : Pelvis, Torso, Head, {L,R}{UpperArm,LowerArm(+hand),UpperLeg,LowerLeg(+foot)}
Anchors (canonical joint positions) are exported so the game can fit each segment onto the
real skeleton at runtime (see src/shared/MeshKit.luau).
"""
import numpy as np

from . import sdf as S

# ---------------------------------------------------------------- canonical skeleton
def joints(b=1.0, f=0.0, height=1.0):
    """b = build (0.85 slim .. 1.25 heavy), f = 0 masculine .. 1 feminine, height scale."""
    h = height
    sh = 0.84 - 0.06 * f
    J = {
        "root": (0, 3.25 * h, 0),
        "waist": (0, 3.62 * h, 0),
        "neck": (0, 5.0 * h, 0.03),
        "head": (0, 5.52 * h, 0.0),
        "headTop": (0, 6.0 * h, 0),
    }
    for side, sx in (("R", 1), ("L", -1)):
        J[side + "shoulder"] = (sx * sh * (0.95 + 0.05 * b), 4.74 * h, 0.03)
        J[side + "elbow"] = (sx * (sh + 0.1), 3.80 * h, 0.06)
        J[side + "wrist"] = (sx * (sh + 0.14), 2.86 * h, 0.0)
        J[side + "handEnd"] = (sx * (sh + 0.15), 2.28 * h, -0.02)
        J[side + "hip"] = (sx * (0.3 + 0.03 * f), 3.06 * h, 0.0)
        J[side + "knee"] = (sx * (0.3 + 0.01 * f), 1.70 * h, -0.03)
        J[side + "ankle"] = (sx * 0.3, 0.36 * h, 0.06)
        J[side + "toe"] = (sx * 0.31, 0.1 * h, -0.62)
        J[side + "ground"] = (sx * 0.3, 0.0, 0.0)
    return {k: np.array(v, float) for k, v in J.items()}


# ---------------------------------------------------------------- anatomy (skin SDFs)
def skin_head(P, J, b, f, face=True):
    c = J["head"]
    skull = S.ellipsoid(P, c + [0, 0.04, 0.03], [0.35, 0.43, 0.41])
    jaw = S.ellipsoid(P, c + [0, -0.2, -0.07], [0.29 - 0.03 * f, 0.22, 0.3])
    chin = S.ellipsoid(P, c + [0, -0.34, -0.25], [0.12, 0.1, 0.1])
    d = S.smooth_union(0.12, skull, jaw, chin)
    if face:
        nose = S.smooth_union(0.04, S.ellipsoid(P, c + [0, -0.04, -0.41], [0.055, 0.13, 0.08]), S.sphere(P, c + [0, -0.13, -0.44], 0.055))
        brow = S.ellipsoid(P, c + [0, 0.11, -0.32], [0.27, 0.045, 0.08])
        cheeks = S.union(S.sphere(P, c + [0.17, -0.07, -0.28], 0.11), S.sphere(P, c + [-0.17, -0.07, -0.28], 0.11))
        lips = S.ellipsoid(P, c + [0, -0.24, -0.35], [0.1, 0.04, 0.05])
        d = S.smooth_union(0.05, d, nose, brow, cheeks, lips)
        sockets = S.union(S.sphere(P, c + [0.13, 0.04, -0.4], 0.075), S.sphere(P, c + [-0.13, 0.04, -0.4], 0.075))
        d = S.subtract(d, sockets, 0.04)
        ears = S.union(S.ellipsoid(P, c + [0.35, 0.0, 0.02], [0.05, 0.12, 0.09]), S.ellipsoid(P, c + [-0.35, 0.0, 0.02], [0.05, 0.12, 0.09]))
        d = S.smooth_union(0.03, d, ears)
    neck = S.round_cone(P, J["neck"] + [0, -0.12, 0], c + [0, -0.25, 0.04], 0.19 * b, 0.16)
    return S.smooth_union(0.08, d, neck)


def eyes(P, J):
    c = J["head"]
    return S.union(S.sphere(P, c + [0.13, 0.04, -0.355], 0.05), S.sphere(P, c + [-0.13, 0.04, -0.355], 0.05))


def irises(P, J):
    c = J["head"]
    return S.union(S.sphere(P, c + [0.13, 0.04, -0.392], 0.022), S.sphere(P, c + [-0.13, 0.04, -0.392], 0.022))


def skin_chest(P, J, b, f):
    w = J["waist"]
    chest = S.ellipsoid(P, w + [0, 0.82, 0.02], [0.66 * b, 0.62, 0.38 * b])
    ribs = S.ellipsoid(P, w + [0, 0.35, 0.0], [0.56 * b, 0.5, 0.34 * b])
    belly = S.ellipsoid(P, w + [0, 0.0, -0.01], [0.5 * b + 0.04 * f, 0.36, 0.32 * b])
    traps = S.ellipsoid(P, J["neck"] + [0, -0.16, 0.06], [0.4 * b, 0.16, 0.22])
    d = S.smooth_union(0.15, chest, ribs, belly, traps)
    for side in "RL":
        d = S.smooth_union(0.1, d, S.sphere(P, J[side + "shoulder"], 0.18 * b))
    if f > 0:
        for sx in (1, -1):
            d = S.smooth_union(0.08, d, S.sphere(P, w + [sx * 0.22, 0.78, -0.28], 0.17 * f))
    return d


def skin_pelvis(P, J, b, f):
    r = J["root"]
    hips = S.ellipsoid(P, r + [0, 0.02, 0.02], [0.56 * b + 0.08 * f, 0.36, 0.36 * b])
    glutes = S.union(S.ellipsoid(P, r + [0.2, -0.12, 0.16], [0.26, 0.28, 0.24]), S.ellipsoid(P, r + [-0.2, -0.12, 0.16], [0.26, 0.28, 0.24]))
    return S.smooth_union(0.12, hips, glutes)


def limb(P, a, bpt, r1, r2):
    return S.smooth_union(0.06, S.round_cone(P, a, bpt, r1, r2), S.sphere(P, a, r1 * 1.02), S.sphere(P, bpt, r2 * 1.04))


def skin_upper_arm(P, J, s, b):
    sh, el = J[s + "shoulder"], J[s + "elbow"]
    arm = limb(P, sh, el, 0.17 * b, 0.12 * b)
    delt = S.ellipsoid(P, sh + [0.03 * (1 if s == "R" else -1), -0.14, 0], [0.155 * b, 0.25, 0.165 * b])
    return S.smooth_union(0.08, arm, delt)


def skin_lower_arm(P, J, s, b):
    return limb(P, J[s + "elbow"], J[s + "wrist"], 0.12 * b, 0.075 * b)


def skin_hand(P, J, s, b):
    w, e = J[s + "wrist"], J[s + "handEnd"]
    sx = 1 if s == "R" else -1
    palm = S.rbox(P, w + [0, -0.2, -0.01], [0.055 * b, 0.15, 0.12], 0.045)
    fingers = S.union(*[S.capsule(P, w + [0, -0.3, -0.09 + i * 0.06], e + [0, 0.04, -0.09 + i * 0.06], 0.03) for i in range(4)])
    thumb = S.capsule(P, w + [sx * 0.02, -0.12, -0.12], w + [sx * 0.03, -0.3, -0.2], 0.035)
    return S.smooth_union(0.03, palm, fingers, thumb, S.sphere(P, w, 0.07))


def skin_upper_leg(P, J, s, b):
    hip, kn = J[s + "hip"], J[s + "knee"]
    return S.smooth_union(0.1, limb(P, hip, kn, 0.26 * b, 0.16 * b), S.ellipsoid(P, (hip + kn) / 2 + [0, 0.15, -0.04], [0.22 * b, 0.45, 0.22 * b]))


def skin_lower_leg(P, J, s, b):
    kn, an = J[s + "knee"], J[s + "ankle"]
    calf = S.ellipsoid(P, kn + [0, -0.42, 0.07], [0.15 * b, 0.36, 0.15 * b])
    return S.smooth_union(0.08, limb(P, kn, an, 0.16 * b, 0.09 * b), calf)


def skin_foot(P, J, s, b):
    an, toe = J[s + "ankle"], J[s + "toe"]
    return S.smooth_union(0.06, S.sphere(P, an, 0.1), S.round_cone(P, an + [0, -0.18, 0.04], toe + [0, 0.02, 0], 0.13, 0.08))


# ---------------------------------------------------------------- clothing helpers
def cloth(d, thickness, P, fold_axis=(0, 1, 0), fold_freq=6.0, fold_amp=0.012, seed=0):
    return d - thickness + S.folds(P, fold_axis, fold_freq, fold_amp, seed)


def above(P, y, k=0.03):
    return -(P[:, 1] - y)  # inside when P.y > y


def below(P, y):
    return P[:, 1] - y  # inside when P.y < y


# ---------------------------------------------------------------- outfits
# An outfit returns, for each segment, a list of (layer, sdf, material, color).
def palette(o, key, default):
    return o.get(key, default)


def build_segments(o, b=1.0, f=0.0, height=1.0):
    """o = outfit dict. Returns ({segment: [(layer, fn, material, color)]}, joints)."""
    J = joints(b, f, height)
    skin = palette(o, "skin", (0.76, 0.6, 0.5))
    top = palette(o, "top", (0.24, 0.3, 0.33))
    pants = palette(o, "pants", (0.2, 0.19, 0.17))
    boots = palette(o, "boots", (0.18, 0.14, 0.11))
    gear = palette(o, "gear", (0.36, 0.33, 0.25))
    strap = (0.16, 0.13, 0.11)
    style = o.get("style", "crew")
    seg = {}

    # ---- head
    head_layers = []
    mask = o.get("mask")
    head_layers.append(("Skin", lambda P: skin_head(P, J, b, f), "SmoothPlastic", skin))
    head_layers.append(("Eyes", lambda P: eyes(P, J), "SmoothPlastic", (0.86, 0.84, 0.8)))
    head_layers.append(("Iris", lambda P: irises(P, J), "SmoothPlastic", palette(o, "iris", (0.2, 0.14, 0.1))))
    hc = J["head"]
    if mask:
        head_layers.append(("Mask", lambda P: cloth(S.intersect(skin_head(P, J, b, f, face=False), below(P, hc[1] - 0.05), 0.03), 0.035, P, (0.2, 1, 0), 4, 0.006, 3), "Fabric", mask))
    hat = o.get("hat")
    hatc = palette(o, "hatColor", (0.25, 0.22, 0.2))
    hair = palette(o, "hair", (0.12, 0.09, 0.07))
    if hat == "beanie":
        head_layers.append(("Hat", lambda P: cloth(S.intersect(S.ellipsoid(P, hc + [0, 0.1, 0.04], [0.39, 0.42, 0.45]), above(P, hc[1] + 0.06), 0.03) - S.knit(P, (0, 1, 0)), 0.0, P, (0, 1, 0), 3, 0.004, 4), "Fabric", hatc))
        head_layers.append(("Hair", lambda P: S.intersect(S.ellipsoid(P, hc + [0, -0.02, 0.1], [0.37, 0.36, 0.38]), S.subtract(above(P, hc[1] - 0.2), S.sphere(P, hc + [0, -0.15, -0.3], 0.38)), 0.03), "Fabric", hair))
    elif hat == "cap":
        head_layers.append(("Hat", lambda P: S.union(S.intersect(S.ellipsoid(P, hc + [0, 0.12, 0.03], [0.38, 0.38, 0.43]), above(P, hc[1] + 0.1), 0.02), S.rbox(P, hc + [0, 0.12, -0.46], [0.24, 0.02, 0.16], 0.02, S.rot_matrix(-0.15, 0, 0))), "Fabric", hatc))
        head_layers.append(("Hair", lambda P: S.intersect(S.ellipsoid(P, hc + [0, 0.0, 0.08], [0.37, 0.38, 0.4]), S.subtract(above(P, hc[1] - 0.1), S.sphere(P, hc + [0, -0.1, -0.3], 0.38)), 0.03), "Fabric", hair))
    elif hat == "bun":
        head_layers.append(("Hair", lambda P: S.smooth_union(0.05, S.intersect(S.ellipsoid(P, hc + [0, 0.06, 0.06], [0.38, 0.43, 0.43]), S.subtract(above(P, hc[1] - 0.12), S.sphere(P, hc + [0, -0.12, -0.32], 0.4)), 0.03), S.sphere(P, hc + [0, 0.18, 0.44], 0.16)), "Fabric", hair))
    elif hat == "hood":
        head_layers.append(("Hood", lambda P: cloth(S.subtract(S.ellipsoid(P, hc + [0, 0.04, 0.1], [0.47, 0.55, 0.56]), S.union(S.ellipsoid(P, hc + [0, -0.02, 0.02], [0.4, 0.48, 0.48]), S.ellipsoid(P, hc + [0, -0.05, -0.42], [0.3, 0.38, 0.3]))), 0.0, P, (0, 1, 0.3), 5, 0.01, 6), "Fabric", hatc))
    elif hat == "helmet":
        head_layers.append(("Helmet", lambda P: S.union(S.intersect(S.ellipsoid(P, hc + [0, 0.1, 0.03], [0.44, 0.46, 0.5]), above(P, hc[1] + 0.02), 0.02), S.intersect(S.ellipsoid(P, hc + [0, 0.04, 0.06], [0.48, 0.12, 0.54]), above(P, hc[1] + 0.0))), "Plastic", hatc))
        head_layers.append(("Hair", lambda P: S.intersect(S.ellipsoid(P, hc + [0, -0.04, 0.1], [0.36, 0.34, 0.38]), above(P, hc[1] - 0.18), 0.03), "Fabric", hair))
    elif hat == "cowl":
        def cowl(P):
            outer = S.smooth_union(0.15, S.ellipsoid(P, hc + [0, 0.04, 0.1], [0.5, 0.58, 0.58]), S.ellipsoid(P, J["neck"] + [0, -0.1, 0.08], [0.55, 0.22, 0.45]))
            inner = S.ellipsoid(P, hc + [0, -0.01, 0.03], [0.4, 0.49, 0.49])
            opening = S.ellipsoid(P, hc + [0, -0.08, -0.5], [0.33, 0.45, 0.4])
            return cloth(S.subtract(S.subtract(outer, inner, 0.02), opening, 0.05), 0.0, P, (0, 1, 0.2), 3, 0.01, 7)
        head_layers.append(("Hood", cowl, "Fabric", hatc))
    if o.get("facePaint"):
        # ash-grey tide lines painted across the eyes (Tidebound)
        head_layers.append(("Paint", lambda P: S.intersect(skin_head(P, J, b, f) - 0.012, S.rbox(P, hc + [0, 0.04, -0.4], [0.3, 0.045, 0.12], 0.02)), "SmoothPlastic", o["facePaint"]))
    hs = o.get("headScale", 1.1)
    hc_ = J["head"] + [0, -0.3, 0]  # scale about the jaw so the neck still meets the torso

    def scaled(fn):
        return lambda P: fn(hc_ + (P - hc_) / hs) * hs
    seg["Head"] = [(n_, scaled(fn_), m_, c_) for n_, fn_, m_, c_ in head_layers]

    # ---- upper torso
    w = J["waist"]
    ut = []
    if style == "robe":
        ut.append(("Robe", lambda P: cloth(S.smooth_union(0.12, skin_chest(P, J, b, f), S.ellipsoid(P, J["neck"] + [0, -0.05, 0.05], [0.32, 0.12, 0.3])), 0.07, P, (0.2, 1, 0), 5, 0.02, 11), "Fabric", top))
        ut.append(("Rope", lambda P: S.torus(P, w + [0, 0.02, 0], 0.5 * b, 0.035), "Fabric", strap))
    else:
        jacket = lambda P: cloth(skin_chest(P, J, b, f), 0.06, P, (0.3, 1, 0), 4.5, 0.01, 1)
        def jacket_full(P):
            d = jacket(P)
            collar = S.subtract(S.round_cone(P, J["neck"] + [0, -0.08, 0.02], J["neck"] + [0, 0.12, 0.04], 0.27, 0.24), S.round_cone(P, J["neck"] + [0, -0.2, 0.02], J["neck"] + [0, 0.3, 0.04], 0.19, 0.19))
            zip_ = S.intersect(S.shell(skin_chest(P, J, b, f) - 0.065, 0.02), S.rbox(P, w + [0, 0.62, -0.4], [0.045, 0.75, 0.3], 0.01))
            pockets = S.union(S.rbox(P, w + [0.25, 0.05, -0.36 * b], [0.14, 0.12, 0.05], 0.03), S.rbox(P, w + [-0.25, 0.05, -0.36 * b], [0.14, 0.12, 0.05], 0.03))
            return S.smooth_union(0.03, d, collar, zip_, pockets)
        ut.append(("Jacket", jacket_full, "Fabric", top))
        if o.get("vest"):
            ut.append(("Vest", lambda P: S.smooth_union(0.03, S.intersect(cloth(skin_chest(P, J, b, f), 0.13, P, (0, 1, 0), 3, 0.004, 2), S.intersect(above(P, w[1] - 0.05), below(P, J["neck"][1] - 0.15))), S.union(*[S.rbox(P, w + [x, 0.25, -0.5 * b], [0.09, 0.13, 0.07], 0.03) for x in (-0.3, -0.1, 0.1, 0.3)])), "Fabric", o["vest"]))
        if o.get("scarf"):
            ut.append(("Scarf", lambda P: cloth(S.smooth_union(0.06, S.torus(P, J["neck"] + [0, -0.12, 0.0], 0.27, 0.11), S.capsule(P, J["neck"] + [0.14, -0.18, -0.28], w + [0.2, 0.62, -0.46], 0.075)), 0.0, P, (0, 1, 0), 5, 0.01, 9) - S.knit(P, (0, 1, 0), 18, 0.004), "Fabric", o["scarf"]))
    if o.get("pack", True) and style != "robe":
        def pack(P):
            body = S.rbox(P, w + [0, 0.62, 0.55 * b], [0.4, 0.5, 0.2], 0.1)
            pocket = S.rbox(P, w + [0, 0.32, 0.77 * b], [0.27, 0.18, 0.08], 0.05)
            roll = S.capsule(P, w + [-0.42, 1.18, 0.5 * b], w + [0.42, 1.18, 0.5 * b], 0.15)
            return S.smooth_union(0.03, body + S.fbm(P, 6, 2) * 0.008, pocket, roll)
        ut.append(("Pack", pack, "Fabric", gear))
        def straps(P):
            parts = []
            for sx in (1, -1):
                top_ = J["neck"] + [sx * 0.24, -0.12, 0.02]
                front = w + [sx * 0.22, 0.25, -0.43 * b]
                over = J["neck"] + [sx * 0.26, -0.05, -0.2]
                back = w + [sx * 0.25, 0.45, 0.4 * b]
                parts += [S.capsule(P, front, over, 0.04), S.capsule(P, over, top_, 0.04), S.capsule(P, top_, back, 0.04)]
            return S.union(*parts)
        ut.append(("Straps", straps, "Leather", strap))
    elif style == "robe":
        ut.append(("Satchel", lambda P: S.rbox(P, w + [0.3, 0.1, 0.42], [0.2, 0.22, 0.1], 0.07), "Fabric", gear))
    if o.get("flashlight", True):
        fl = J["Lshoulder"] + [0.32, -0.38, -0.36 * b]
        ut.append(("Flashlight", lambda P: S.smooth_union(0.02, S.cylinder(P, fl + [0, 0, 0.06], fl + [0, 0, -0.14], 0.055, 0.01), S.cylinder(P, fl + [0, 0, -0.14], fl + [0, 0, -0.2], 0.075, 0.01)), "Metal", (0.12, 0.12, 0.12)))
    seg["UpperTorso"] = ut

    # ---- lower torso (pelvis)
    r = J["root"]
    lt = []
    if style == "robe":
        lt.append(("Robe", lambda P: cloth(S.smooth_union(0.12, skin_pelvis(P, J, b, f), S.round_cone(P, r + [0, 0.2, 0], r + [0, -1.15, 0.02], 0.5 * b, 0.6 * b)), 0.04, P, (0, 0, 1), 3.0, 0.018, 12), "Fabric", top))
    else:
        lt.append(("Pants", lambda P: cloth(skin_pelvis(P, J, b, f), 0.045, P, (1, 0.3, 0), 6, 0.01, 2), "Fabric", pants))
        lt.append(("Belt", lambda P: S.intersect(S.shell(skin_pelvis(P, J, b, f) - 0.06, 0.03), S.intersect(above(P, r[1] + 0.12), below(P, r[1] + 0.24))), "Leather", strap))
        if style == "crew" and o.get("jacketLong", True):
            lt.append(("JacketHem", lambda P: cloth(S.intersect(skin_pelvis(P, J, b, f) - 0.08, S.intersect(above(P, r[1] + 0.05), below(P, r[1] + 0.42))), 0.0, P, (0, 1, 0), 5, 0.01, 5), "Fabric", top))
        if o.get("toolbelt"):
            lt.append(("Pouches", lambda P: S.union(S.rbox(P, r + [0.42, 0.05, -0.12], [0.08, 0.14, 0.12], 0.03), S.rbox(P, r + [-0.42, 0.05, -0.12], [0.08, 0.14, 0.12], 0.03)), "Leather", (0.3, 0.22, 0.15)))
    seg["LowerTorso"] = lt

    # ---- limbs
    for s in "RL":
        sleeve_color = top
        seg[s + "UpperArm"] = [("Sleeve", (lambda s=s: lambda P: cloth(skin_upper_arm(P, J, s, b), 0.055 if style != "robe" else 0.09, P, J[s + "elbow"] - J[s + "shoulder"], 6, 0.014, 20))(), "Fabric", sleeve_color)]
        la = [("Sleeve", (lambda s=s: lambda P: cloth(S.intersect(skin_lower_arm(P, J, s, b), above(P, J[s + "wrist"][1] + (0.12 if style != "robe" else 0.25))), 0.05 if style != "robe" else 0.1, P, J[s + "wrist"] - J[s + "elbow"], 7, 0.012, 21))(), "Fabric", sleeve_color)]
        la.append(("Skin", (lambda s=s: lambda P: S.intersect(skin_lower_arm(P, J, s, b), below(P, J[s + "wrist"][1] + 0.2)))(), "SmoothPlastic", skin))
        if style == "robe":
            la.append(("Wraps", (lambda s=s: lambda P: S.intersect(S.shell(skin_lower_arm(P, J, s, b) - 0.015, 0.012), S.intersect(below(P, J[s + "wrist"][1] + 0.3), above(P, J[s + "wrist"][1] - 0.02))))(), "Fabric", (0.6, 0.56, 0.48)))
        seg[s + "LowerArm"] = la
        gloves = o.get("gloves")
        seg[s + "Hand"] = [("Glove" if gloves else "Skin", (lambda s=s: lambda P: skin_hand(P, J, s, b) - (0.012 if gloves else 0))(), "Leather" if gloves else "SmoothPlastic", gloves or skin)]
        if style == "robe":
            seg[s + "UpperLeg"] = [("Robe", (lambda s=s: lambda P: cloth(S.round_cone(P, J[s + "hip"] + [0, 0.05, 0], J[s + "knee"] + [0, -0.15, 0], 0.3 * b, 0.33 * b), 0.0, P, (0, 0, 1), 3.0, 0.015, 13))(), "Fabric", top)]
        else:
            seg[s + "UpperLeg"] = [("Pants", (lambda s=s: lambda P: cloth(skin_upper_leg(P, J, s, b), 0.04, P, J[s + "knee"] - J[s + "hip"], 6, 0.013, 22))(), "Fabric", pants)]
            if o.get("kneePads"):
                seg[s + "UpperLeg"].append(("Pad", (lambda s=s: lambda P: S.ellipsoid(P, J[s + "knee"] + [0, 0.02, -0.17], [0.15, 0.17, 0.08]))(), "Plastic", o["kneePads"]))
        seg[s + "LowerLeg"] = [
            ("Pants", (lambda s=s: lambda P: cloth(S.intersect(skin_lower_leg(P, J, s, b), above(P, J[s + "ankle"][1] + 0.5)), 0.045, P, J[s + "ankle"] - J[s + "knee"], 6, 0.014, 23))(), "Fabric", pants if style != "robe" else (0.42, 0.38, 0.32)),
            ("Boot", (lambda s=s: lambda P: cloth(S.intersect(skin_lower_leg(P, J, s, b), below(P, J[s + "ankle"][1] + 0.55)), 0.06, P, (0, 1, 0), 9, 0.006, 24))(), "Leather", boots),
        ]
        seg[s + "Foot"] = [("Boot", (lambda s=s: lambda P: S.smooth_union(0.03, skin_foot(P, J, s, b) - 0.06, S.rbox(P, (J[s + "ankle"] + J[s + "toe"]) / 2 + [0, -0.17, -0.05], [0.15, 0.04, 0.42], 0.03)))(), "Leather", boots)]
    return seg, J


# ---------------------------------------------------------------- segment geometry
def segment_bounds(name, J):
    """Bounding box (lo, hi) to mesh each segment in."""
    pad = 0.35
    pts = {
        "Head": [J["head"] + [0, 0.65, 0], J["neck"] + [0, -0.25, 0]],
        "UpperTorso": [J["waist"] + [0, -0.1, 0], J["neck"] + [0, 0.35, 0], J["Rshoulder"] + [0.25, 0, 0], J["Lshoulder"] + [-0.25, 0, 0]],
        "LowerTorso": [J["root"] + [0, 0.55, 0], J["root"] + [0, -1.4, 0], J["Rhip"] + [0.35, 0, 0], J["Lhip"] + [-0.35, 0, 0]],
    }
    for s in "RL":
        pts[s + "UpperArm"] = [J[s + "shoulder"], J[s + "elbow"]]
        pts[s + "LowerArm"] = [J[s + "elbow"], J[s + "wrist"]]
        pts[s + "Hand"] = [J[s + "wrist"], J[s + "handEnd"]]
        pts[s + "UpperLeg"] = [J[s + "hip"], J[s + "knee"]]
        pts[s + "LowerLeg"] = [J[s + "knee"], J[s + "ankle"]]
        pts[s + "Foot"] = [J[s + "ankle"], J[s + "toe"]]
    p = np.array(pts[name])
    lo, hi = p.min(0) - pad, p.max(0) + pad
    if name in ("UpperTorso",):
        lo[2] -= 0.1
        hi[2] += 0.75  # backpack
    return lo, hi


# Which canonical joints anchor each segment: (top/attach joint, bottom joint or None).
R15_ANCHORS = {
    "Head": ("neck", None),
    "UpperTorso": ("waist", "neck"),
    "LowerTorso": ("root", "waist"),
}
for _s, _n in (("R", "Right"), ("L", "Left")):
    R15_ANCHORS[_n + "UpperArm"] = (_s + "shoulder", _s + "elbow")
    R15_ANCHORS[_n + "LowerArm"] = (_s + "elbow", _s + "wrist")
    R15_ANCHORS[_n + "Hand"] = (_s + "wrist", None)
    R15_ANCHORS[_n + "UpperLeg"] = (_s + "hip", _s + "knee")
    R15_ANCHORS[_n + "LowerLeg"] = (_s + "knee", _s + "ankle")
    R15_ANCHORS[_n + "Foot"] = (_s + "ankle", None)


def r15_name(seg):
    if seg[0] in "RL" and seg[1:] in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot"):
        return ("Right" if seg[0] == "R" else "Left") + seg[1:]
    return seg
