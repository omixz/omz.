"""Surface nets: SDF -> smooth triangle mesh (vectorised numpy).
mesh(sdf_fn, lo, hi, cell) returns (vertices (V,3), normals (V,3), faces (F,3))."""
import numpy as np

_CORNERS = np.array([[x, y, z] for z in (0, 1) for y in (0, 1) for x in (0, 1)])
_EDGES = []
for a in range(8):
    for b in range(a + 1, 8):
        if np.sum(np.abs(_CORNERS[a] - _CORNERS[b])) == 1:
            _EDGES.append((a, b))


def auto_bounds(sdf_fn, lo, hi, margin=0.06, coarse=0.06):
    """Shrink-wrap a generous search box to where the shape actually is."""
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    vol = float(np.prod(hi - lo))
    coarse = max(coarse, (vol / 1.5e6) ** (1 / 3))  # cap the probe at ~1.5M samples
    n = np.maximum(np.ceil((hi - lo) / coarse).astype(int) + 1, 2)
    xs = [np.linspace(lo[i], hi[i], n[i]) for i in range(3)]
    g = np.stack(np.meshgrid(*xs, indexing="ij"), -1).reshape(-1, 3)
    d = sdf_fn(g)
    inside = g[d < coarse]
    if len(inside) == 0:
        return None, None
    return inside.min(0) - margin - coarse, inside.max(0) + margin + coarse


def mesh(sdf_fn, lo, hi, cell, smooth=1, auto=True):
    lo, hi = np.asarray(lo, float), np.asarray(hi, float)
    if auto:
        lo, hi = auto_bounds(sdf_fn, lo - 0.6, hi + 0.6)
        if lo is None:
            return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3), dtype=np.int64)
    n = np.maximum(np.ceil((hi - lo) / cell).astype(int) + 1, 3)
    xs = [np.linspace(lo[i], lo[i] + cell * (n[i] - 1), n[i]) for i in range(3)]
    gx, gy, gz = np.meshgrid(xs[0], xs[1], xs[2], indexing="ij")
    pts = np.stack([gx.ravel(), gy.ravel(), gz.ravel()], axis=1)
    f = sdf_fn(pts).reshape(n)
    nx, ny, nz = n
    cx, cy, cz = nx - 1, ny - 1, nz - 1

    # corner values per cell: (cx,cy,cz,8)
    cv = np.stack([f[c[0]:c[0] + cx, c[1]:c[1] + cy, c[2]:c[2] + cz] for c in _CORNERS], axis=-1)
    inside = cv < 0
    active = inside.any(-1) & ~inside.all(-1)
    idx = np.argwhere(active)
    if len(idx) == 0:
        return np.zeros((0, 3)), np.zeros((0, 3)), np.zeros((0, 3), dtype=np.int64)
    vals = cv[active]  # (A,8)
    acc = np.zeros((len(idx), 3))
    cnt = np.zeros(len(idx))
    for a, b in _EDGES:
        va, vb = vals[:, a], vals[:, b]
        crossing = (va < 0) != (vb < 0)
        t = np.where(crossing, va / np.where(va - vb == 0, 1e-9, va - vb), 0)
        p = _CORNERS[a] + t[:, None] * (_CORNERS[b] - _CORNERS[a])
        acc += np.where(crossing[:, None], p, 0)
        cnt += crossing
    local = acc / np.maximum(cnt, 1)[:, None]
    verts = lo + (idx + local) * cell

    vid = -np.ones((cx, cy, cz), dtype=np.int64)
    vid[active] = np.arange(len(idx))

    faces = []
    # x-edges: grid points (i,j,k)-(i+1,j,k); neighbour cells (i, j-1..j, k-1..k)
    s = f < 0
    for axis in range(3):
        sl_a = [slice(None)] * 3
        sl_b = [slice(None)] * 3
        sl_a[axis] = slice(0, -1)
        sl_b[axis] = slice(1, None)
        ea, eb = s[tuple(sl_a)], s[tuple(sl_b)]
        change = ea != eb
        # restrict so the 4 neighbouring cells exist
        o1, o2 = [(1, 2), (0, 2), (0, 1)][axis]
        e = np.argwhere(change)
        e = e[(e[:, o1] >= 1) & (e[:, o2] >= 1) & (e[:, o1] < [cx, cy, cz][o1] + 0) & (e[:, o2] < [cx, cy, cz][o2] + 0)]
        e = e[(e[:, axis] < [cx, cy, cz][axis])]
        if len(e) == 0:
            continue
        flip = ea[tuple(e.T)]
        def cell_at(d1, d2):
            c = e.copy()
            c[:, o1] -= d1
            c[:, o2] -= d2
            return vid[c[:, 0], c[:, 1], c[:, 2]]
        v00, v10, v11, v01 = cell_at(1, 1), cell_at(0, 1), cell_at(0, 0), cell_at(1, 0)
        ok = (v00 >= 0) & (v10 >= 0) & (v11 >= 0) & (v01 >= 0)
        v00, v10, v11, v01, flip = v00[ok], v10[ok], v11[ok], v01[ok], flip[ok]
        q = np.stack([v00, v10, v11, v01], axis=1)
        # orientation: make normals point outward (from inside to outside)
        if axis == 1:
            flip = ~flip
        q[flip] = q[flip][:, ::-1]
        faces.append(np.concatenate([q[:, [0, 1, 2]], q[:, [0, 2, 3]]]))
    faces = np.concatenate(faces) if faces else np.zeros((0, 3), dtype=np.int64)

    # light Laplacian smoothing, re-projected towards the surface
    for _ in range(smooth):
        nb_sum = np.zeros_like(verts)
        nb_cnt = np.zeros(len(verts))
        for a, b in ((0, 1), (1, 2), (2, 0)):
            np.add.at(nb_sum, faces[:, a], verts[faces[:, b]])
            np.add.at(nb_cnt, faces[:, a], 1)
        avg = nb_sum / np.maximum(nb_cnt, 1)[:, None]
        verts = verts * 0.5 + avg * 0.5
        verts = _project(sdf_fn, verts, cell)

    normals = _gradient(sdf_fn, verts, cell * 0.5)
    # fix winding to agree with the field normal
    if len(faces):
        tri = verts[faces]
        fn = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        agree = np.sum(fn * normals[faces[:, 0]], axis=1) < 0
        faces[agree] = faces[agree][:, ::-1]
    return verts, normals, faces


def _gradient(sdf_fn, P, eps):
    g = np.zeros_like(P)
    for i in range(3):
        d = np.zeros(3)
        d[i] = eps
        g[:, i] = sdf_fn(P + d) - sdf_fn(P - d)
    n = np.linalg.norm(g, axis=1, keepdims=True)
    return g / np.maximum(n, 1e-9)


def _project(sdf_fn, P, cell):
    d = sdf_fn(P)
    n = _gradient(sdf_fn, P, cell * 0.5)
    return P - n * np.clip(d, -cell, cell)[:, None]
