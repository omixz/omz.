"""Minimal glTF 2.0 binary (GLB) writer: one node + mesh per named part, flat PBR materials.
Each mesh is re-centred on its bounding-box centre (that's where Roblox puts a MeshPart's
pivot), and its original centre is returned so placement metadata can be generated."""
import json
import struct

import numpy as np


def _pad(b, fill=b"\x00"):
    return b + fill * ((4 - len(b) % 4) % 4)


def box_uv(verts, normals):
    a = np.argmax(np.abs(normals), axis=1)
    uv = np.zeros((len(verts), 2))
    uv[a == 0] = verts[a == 0][:, [2, 1]]
    uv[a == 1] = verts[a == 1][:, [0, 2]]
    uv[a == 2] = verts[a == 2][:, [0, 1]]
    return uv * 0.5


def write(path, parts):
    """parts: list of dict(name, verts, normals, faces, color=(r,g,b), roughness, metallic).
    Returns {name: {"center": [...], "size": [...], "tris": n}}."""
    buf = bytearray()
    views, accessors, meshes, nodes, materials = [], [], [], [], []
    meta = {}

    def add_view(data, target):
        offset = len(buf)
        buf.extend(_pad(data))
        views.append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
        return len(views) - 1

    for i, p in enumerate(parts):
        v = np.asarray(p["verts"], np.float64)
        if len(v) == 0 or len(p["faces"]) == 0:
            continue
        lo, hi = v.min(0), v.max(0)
        center = (lo + hi) / 2
        v = (v - center).astype(np.float32)
        nrm = np.asarray(p["normals"], np.float32)
        uv = box_uv(v, nrm).astype(np.float32)
        f = np.asarray(p["faces"], np.uint32).ravel()
        pv = add_view(v.tobytes(), 34962)
        nv = add_view(nrm.tobytes(), 34962)
        tv = add_view(uv.tobytes(), 34962)
        iv = add_view(f.tobytes(), 34963)
        base = len(accessors)
        accessors += [
            {"bufferView": pv, "componentType": 5126, "count": len(v), "type": "VEC3", "min": v.min(0).tolist(), "max": v.max(0).tolist()},
            {"bufferView": nv, "componentType": 5126, "count": len(v), "type": "VEC3"},
            {"bufferView": tv, "componentType": 5126, "count": len(v), "type": "VEC2"},
            {"bufferView": iv, "componentType": 5125, "count": len(f), "type": "SCALAR"},
        ]
        c = p.get("color", (0.7, 0.7, 0.7))
        materials.append({
            "name": p["name"] + "_mat",
            "pbrMetallicRoughness": {
                "baseColorFactor": [c[0], c[1], c[2], 1.0],
                "metallicFactor": p.get("metallic", 0.0),
                "roughnessFactor": p.get("roughness", 0.8),
            },
        })
        meshes.append({"name": p["name"], "primitives": [{"attributes": {"POSITION": base, "NORMAL": base + 1, "TEXCOORD_0": base + 2}, "indices": base + 3, "material": len(materials) - 1}]})
        nodes.append({"name": p["name"], "mesh": len(meshes) - 1, "translation": center.tolist()})
        meta[p["name"]] = {"center": center.tolist(), "size": (hi - lo).tolist(), "tris": int(len(f) // 3)}

    gltf = {
        "asset": {"version": "2.0", "generator": "aftertide-sculpt"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(nodes)))}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(buf)}],
    }
    js = _pad(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
    bin_ = _pad(bytes(buf))
    total = 12 + 8 + len(js) + 8 + len(bin_)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", 0x46546C67, 2, total))
        fh.write(struct.pack("<II", len(js), 0x4E4F534A))
        fh.write(js)
        fh.write(struct.pack("<II", len(bin_), 0x004E4942))
        fh.write(bin_)
    return meta
