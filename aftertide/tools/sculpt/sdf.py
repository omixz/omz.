"""Signed distance field primitives and operators (numpy, vectorised).
Every function takes P: (N,3) float array and returns (N,) distances (negative = inside).
Coordinates: Roblox convention (Y up, -Z forward, +X = character's right)."""
import numpy as np


def _len(v):
    return np.sqrt(np.sum(v * v, axis=-1))


def sphere(P, c, r):
    return _len(P - np.asarray(c, float)) - r


def ellipsoid(P, c, radii):
    # good approximation (iq's ellipsoid bound)
    r = np.asarray(radii, float)
    q = (P - np.asarray(c, float))
    k0 = _len(q / r)
    k1 = _len(q / (r * r))
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def capsule(P, a, b, r):
    a, b = np.asarray(a, float), np.asarray(b, float)
    pa, ba = P - a, b - a
    h = np.clip(np.sum(pa * ba, axis=-1) / np.dot(ba, ba), 0, 1)
    return _len(pa - h[:, None] * ba) - r


def round_cone(P, a, b, r1, r2):
    """Capsule whose radius tapers from r1 (at a) to r2 (at b)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    l2 = np.dot(ba, ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = P - a
    y = np.sum(pa * ba, axis=-1)
    z = y - l2
    xv = pa * l2 - y[:, None] * ba
    x2 = np.sum(xv * xv, axis=-1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = np.sign(rr) * rr * rr * x2
    out = np.empty(len(P))
    m1 = np.sign(z) * a2 * z2 > k
    m2 = np.sign(y) * a2 * y2 < k
    out[m1] = np.sqrt(x2[m1] + z2[m1]) * il2 - r2
    out[m2 & ~m1] = np.sqrt(x2[m2 & ~m1] + y2[m2 & ~m1]) * il2 - r1
    rest = ~(m1 | m2)
    out[rest] = (np.sqrt(x2[rest] * a2 * il2) + y[rest] * rr) * il2 - r1
    return out


def rot_matrix(rx=0.0, ry=0.0, rz=0.0):
    cx, sx, cy, sy, cz, sz = np.cos(rx), np.sin(rx), np.cos(ry), np.sin(ry), np.cos(rz), np.sin(rz)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def rbox(P, c, half, r=0.0, rot=None):
    """Rounded box. half = half extents (before rounding). rot = 3x3 world-from-local."""
    q = P - np.asarray(c, float)
    if rot is not None:
        q = q @ np.asarray(rot)  # world -> local (R^T applied on the right)
    d = np.abs(q) - (np.asarray(half, float) - r)
    outside = _len(np.maximum(d, 0))
    inside = np.minimum(np.max(d, axis=-1), 0)
    return outside + inside - r


def cylinder(P, a, b, r, rounding=0.0):
    """Capped cylinder between points a and b."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ba = b - a
    pa = P - a
    baba = np.dot(ba, ba)
    paba = np.sum(pa * ba, axis=-1)
    x = _len(pa * baba - paba[:, None] * ba) - (r - rounding) * baba
    y = np.abs(paba - baba * 0.5) - baba * 0.5
    x2, y2 = x * x, y * y * baba
    d = np.where(np.maximum(x, y) < 0, -np.minimum(x2, y2), np.where(x > 0, x2, 0) + np.where(y > 0, y2, 0))
    return np.sign(d) * np.sqrt(np.abs(d)) / baba - rounding


def torus(P, c, R, r, axis="y"):
    q = P - np.asarray(c, float)
    if axis == "y":
        a, b, h = q[:, 0], q[:, 2], q[:, 1]
    elif axis == "x":
        a, b, h = q[:, 1], q[:, 2], q[:, 0]
    else:
        a, b, h = q[:, 0], q[:, 1], q[:, 2]
    return np.sqrt((np.sqrt(a * a + b * b) - R) ** 2 + h * h) - r


def plane_y(P, y):
    return P[:, 1] - y


# ------------------------------------------------------------ operators
def union(*ds):
    out = ds[0]
    for d in ds[1:]:
        out = np.minimum(out, d)
    return out


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smooth_union(k, *ds):
    out = ds[0]
    for d in ds[1:]:
        out = smin(out, d, k)
    return out


def subtract(a, b, k=0.0):
    """a minus b (smooth if k>0)."""
    if k <= 0:
        return np.maximum(a, -b)
    h = np.clip(0.5 - 0.5 * (a + b) / k, 0, 1)
    return a * (1 - h) + (-b) * h + k * h * (1 - h)


def intersect(a, b, k=0.0):
    if k <= 0:
        return np.maximum(a, b)
    h = np.clip(0.5 - 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h + k * h * (1 - h)


def shell(d, thickness):
    return np.abs(d) - thickness


# ------------------------------------------------------------ noise
_PERM = np.random.default_rng(7).permutation(256)
_PERM = np.concatenate([_PERM, _PERM])
_GRAD = np.random.default_rng(11).normal(size=(256, 3))
_GRAD /= np.linalg.norm(_GRAD, axis=1, keepdims=True)


def _fade(t):
    return t * t * t * (t * (t * 6 - 15) + 10)


def perlin(P, freq=1.0, seed=0):
    """Gradient noise in roughly [-1, 1]."""
    q = P * freq + seed * 17.13
    i0 = np.floor(q).astype(np.int64)
    f = q - i0
    u = _fade(f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                ix = (i0[:, 0] + dx) & 255
                iy = (i0[:, 1] + dy) & 255
                iz = (i0[:, 2] + dz) & 255
                h = _PERM[_PERM[_PERM[ix] + iy] + iz]
                g = _GRAD[h]
                d = f - np.array([dx, dy, dz])
                dot = np.sum(g * d, axis=-1)
                wx = u[:, 0] if dx else 1 - u[:, 0]
                wy = u[:, 1] if dy else 1 - u[:, 1]
                wz = u[:, 2] if dz else 1 - u[:, 2]
                out = out + dot * wx * wy * wz
    return out * 1.6


def fbm(P, freq=1.0, octaves=4, gain=0.5, seed=0):
    amp, total, norm = 1.0, 0.0, 0.0
    for o in range(octaves):
        total = total + perlin(P, freq * (2 ** o), seed + o) * amp
        norm += amp
        amp *= gain
    return total / norm


def folds(P, axis_dir, freq=8.0, amp=0.012, seed=0):
    """Soft cloth folds: gentle ridges perpendicular to an axis, slowly warped, plus broad
    low-frequency bulges. Kept subtle: real fabric reads as smooth at game distance."""
    a = np.asarray(axis_dir, float)
    a = a / np.linalg.norm(a)
    t = P @ a
    warp = perlin(P, 1.6, seed) * 0.35
    ridges = np.sin((t + warp) * freq * 2 * np.pi)
    ridges = np.sign(ridges) * np.abs(ridges) ** 2.5  # sharper creases, flat between
    mask = np.clip(perlin(P, 2.2, seed + 3) * 1.4 + 0.3, 0, 1)
    bulge = perlin(P, 1.2, seed + 9)
    return ridges * amp * 0.6 * mask + bulge * amp * 0.7


def knit(P, axis_dir, freq=26.0, amp=0.004):
    """Fine rib knit (beanies, scarves)."""
    a = np.asarray(axis_dir, float)
    a = a / np.linalg.norm(a)
    return np.abs(np.sin(np.arctan2(P[:, 2], P[:, 0]) * freq)) * amp


# ------------------------------------------------------------------ profiles
def poly2d(px, py, verts):
    """Signed distance to a closed 2D polygon (vectorised; negative inside)."""
    v = np.asarray(verts, float)
    d = (px - v[0, 0]) ** 2 + (py - v[0, 1]) ** 2
    s = np.ones_like(px)
    n = len(v)
    for i in range(n):
        j = (i - 1) % n
        ex, ey = v[j, 0] - v[i, 0], v[j, 1] - v[i, 1]
        wx, wy = px - v[i, 0], py - v[i, 1]
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
        bx, by = wx - ex * t, wy - ey * t
        d = np.minimum(d, bx * bx + by * by)
        c1 = py >= v[i, 1]
        c2 = py < v[j, 1]
        c3 = ex * wy > ey * wx
        flip = (c1 & c2 & c3) | (~c1 & ~c2 & ~c3)
        s = np.where(flip, -s, s)
    return s * np.sqrt(d)


def smooth_poly(points, iterations=2):
    """Chaikin corner cutting: turns a coarse outline into a smooth curve."""
    p = np.asarray(points, float)
    for _ in range(iterations):
        q = 0.75 * p + 0.25 * np.roll(p, -1, 0)
        r = 0.25 * p + 0.75 * np.roll(p, -1, 0)
        p = np.empty((len(p) * 2, 2))
        p[0::2], p[1::2] = q, r
    return p


def extrude_zy(P, profile, half_width, r=0.0):
    """A side profile (points as (z, y)) extruded across X, with rounded edges.
    half_width may be a number or a function of z (e.g. a stock that widens to the butt)."""
    d2 = poly2d(P[:, 2], P[:, 1], profile)
    hw = half_width(P[:, 2]) if callable(half_width) else half_width
    qx = d2 + r
    qy = np.abs(P[:, 0]) - hw + r
    outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    return outside + np.minimum(np.maximum(qx, qy), 0) - r
