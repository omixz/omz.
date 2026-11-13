"""Tiny software renderer for checking sculpts: shaded, depth-sorted triangles -> PNG."""
import numpy as np
from PIL import Image, ImageDraw


def render(parts, path, size=(900, 900), yaw=25.0, pitch=10.0, bg=(28, 30, 32), views=1):
    """parts: list of (verts, faces, rgb 0..1). Renders `views` side-by-side turnarounds."""
    W, H = size
    img = Image.new("RGB", (W * views, H), bg)
    draw = ImageDraw.Draw(img)
    allv = np.concatenate([p[0] for p in parts if len(p[0])])
    lo, hi = allv.min(0), allv.max(0)
    center = (lo + hi) / 2
    extent = np.max(hi - lo) * 0.55
    light = np.array([-0.4, 0.8, -0.6])
    light /= np.linalg.norm(light)
    for vi in range(views):
        yw = np.radians(yaw + vi * (360.0 / views))
        pt = np.radians(pitch)
        Ry = np.array([[np.cos(yw), 0, np.sin(yw)], [0, 1, 0], [-np.sin(yw), 0, np.cos(yw)]])
        Rx = np.array([[1, 0, 0], [0, np.cos(pt), -np.sin(pt)], [0, np.sin(pt), np.cos(pt)]])
        R = Rx @ Ry
        tris_all = []
        for verts, faces, rgb in parts:
            if len(faces) == 0:
                continue
            v = (verts - center) @ R.T
            tri = v[faces]
            n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
            n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
            facing = n[:, 2] < 0  # camera looks down +Z towards -Z... we view from -Z
            depth = tri[:, :, 2].mean(1)
            lit = np.clip((n @ (R @ light)), 0, 1) * 0.75 + np.clip(-(n @ (R @ light)), 0, 1) * 0.15 + 0.25
            for t, d, l, f in zip(tri, depth, lit, facing):
                if f:
                    tris_all.append((d, t, l, rgb))
        tris_all.sort(key=lambda x: -x[0])
        scale = (H * 0.5) / extent
        for d, t, l, rgb in tris_all:
            pts = [(W * vi + W / 2 + p[0] * scale, H / 2 - p[1] * scale) for p in t]
            col = tuple(int(min(255, 255 * (c * l * 1.25) ** (1 / 2.2))) for c in rgb)
            draw.polygon(pts, fill=col)
    img.save(path)
