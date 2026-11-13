"""Collects sculpted assets into packs: meshes -> one GLB per pack + placement metadata."""
import time

import numpy as np

from . import glb, mesher, preview, textures

TRI_BUDGET = 12000  # per MeshPart (Roblox limit is ~20k; lighter is faster on phones)


def mesh_budget(fn, lo, hi, cell):
    v, n, f = mesher.mesh(fn, lo, hi, cell)
    tries = 0
    while len(f) > TRI_BUDGET and tries < 4:
        cell *= (len(f) / TRI_BUDGET) ** 0.5 * 1.05
        v, n, f = mesher.mesh(fn, lo, hi, cell)
        tries += 1
    return v, n, f


class Pack:
    def __init__(self, name):
        self.name = name
        self.parts = []
        self.meta = {}
        self.previews = {}

    def add_rig(self, kit, segments, bounds_fn, anchors, J, cell=0.04, fine=None, rename=None):
        """A rigged kit: segments -> layers, each anchored to the skeleton."""
        fine = fine or {}
        t0 = time.time()
        entry = {"type": "rig", "segments": {}}
        prev = []
        for seg, layers in segments.items():
            lo, hi = bounds_fn(seg, J)
            segname = rename(seg) if rename else seg
            top, bottom = anchors.get(segname, (None, None))
            s = {"top": _r(J[top]) if top else None, "bottom": _r(J[bottom]) if bottom else None, "layers": {}}
            for layer, fn, material, color in layers:
                if isinstance(fn, tuple):
                    v, n, f = fn  # exact geometry (e.g. faceted crystals)
                    f = np.asarray(f).reshape(-1, 3)
                else:
                    v, n, f = mesh_budget(fn, lo, hi, fine.get(seg, cell))
                if len(f) == 0:
                    continue
                pname = f"{kit}_{segname}_{layer}"
                self.parts.append({"name": pname, "verts": v, "normals": n, "faces": f, "color": color, "tex": textures.kind_for(material, layer)})
                s["layers"][layer] = {"part": pname, "material": material, "color": _r(color)}
                prev.append((v, f, color))
            entry["segments"][segname] = s
        self.meta[kit] = entry
        self.previews[kit] = prev
        print(f"  {kit}: {time.time() - t0:.1f}s")

    def add_prop(self, kit, cell, layers, search=((-12, -1, -12), (12, 40, 12))):
        t0 = time.time()
        entry = {"type": "prop", "layers": {}}
        prev = []
        for layer, src, material, color in layers:
            if isinstance(src, tuple):
                v, n, f = src
            else:
                v, n, f = mesh_budget(src, search[0], search[1], cell)
            if len(f) == 0:
                continue
            pname = f"{kit}_{layer}"
            self.parts.append({"name": pname, "verts": v, "normals": n, "faces": f, "color": color, "tex": textures.kind_for(material, layer)})
            entry["layers"][layer] = {"part": pname, "material": material, "color": _r(color)}
            prev.append((v, f, color))
        self.meta[kit] = entry
        self.previews[kit] = prev
        print(f"  {kit}: {time.time() - t0:.1f}s")

    def write(self, glb_path, preview_dir=None):
        info = glb.write(glb_path, self.parts)
        tris = 0
        for kit, entry in self.meta.items():
            layer_groups = entry["segments"].values() if entry["type"] == "rig" else [entry]
            for group in layer_groups:
                for L in group["layers"].values():
                    i = info[L["part"]]
                    L["center"] = _r(i["center"])
                    L["size"] = _r(i["size"])
                    L["tris"] = i["tris"]
                    tris += i["tris"]
        if preview_dir:
            for kit, prev in self.previews.items():
                if prev:
                    preview.render(prev, f"{preview_dir}/{kit}.png", size=(420, 600), yaw=200, pitch=8, views=3)
        print(f"PACK {self.name}: {len(self.parts)} meshes, {tris} triangles")
        return self.meta


def _r(x):
    return [round(float(v), 4) for v in np.asarray(x).ravel()]
