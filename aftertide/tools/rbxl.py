"""Minimal writer for Roblox's binary place format (.rbxl), used by build_place.py so the place
can be published through Open Cloud (which rejects our XML files).

Format summary (chunks are written uncompressed: compressedLength = 0):
  header "<roblox!" + magic + version(u16) + classes(i32) + instances(i32) + 8 zero bytes
  INST  per class: classId, className, isService, count, referents (delta, zigzag, interleaved)
  PROP  per class+property: classId, name, typeId, values
  PRNT  version 0, count, child referents, parent referents (-1 = no parent)
  END   "</roblox>"
Supported property types: string (0x01), bool (0x02), float (0x04), token/enum (0x12)."""
import struct

MAGIC = b"<roblox!\x89\xff\x0d\x0a\x1a\x0a"
SERVICES = {"Workspace", "Lighting", "Players", "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "SoundService", "StarterGui", "StarterPack", "Teams"}


class Inst:
    def __init__(self, class_name, name, props=None, children=None):
        self.class_name = class_name
        self.props = {"Name": ("string", name)}
        self.props.update(props or {})
        self.children = children or []


def _string(s):
    b = s.encode("utf-8") if isinstance(s, str) else s
    return struct.pack("<I", len(b)) + b


def _interleave(words):
    """List of 4-byte big-endian words -> interleaved byte planes."""
    if not words:
        return b""
    return bytes(w[i] for i in range(4) for w in words)


def _zigzag(v):
    return ((v << 1) ^ (v >> 31)) & 0xFFFFFFFF


def _ints(values, delta=False):
    out, prev = [], 0
    for v in values:
        x = v - prev if delta else v
        prev = v
        out.append(struct.pack(">I", _zigzag(x)))
    return _interleave(out)


def _floats(values):
    words = []
    for v in values:
        bits = struct.unpack(">I", struct.pack(">f", v))[0]
        words.append(struct.pack(">I", ((bits << 1) | (bits >> 31)) & 0xFFFFFFFF))
    return _interleave(words)


def _chunk(name, data):
    return name + struct.pack("<III", 0, len(data), 0) + data


def write(roots, path):
    # flatten, assign referents
    order = []

    def walk(inst, parent):
        inst.ref = len(order)
        inst.parent = parent
        order.append(inst)
        for c in inst.children:
            walk(c, inst)

    for r in roots:
        walk(r, None)
    classes = {}
    for inst in order:
        classes.setdefault(inst.class_name, []).append(inst)
    class_ids = {name: i for i, name in enumerate(sorted(classes))}

    out = bytearray()
    out += MAGIC + struct.pack("<H", 0) + struct.pack("<ii", len(classes), len(order)) + b"\x00" * 8
    for name in sorted(classes):
        insts = classes[name]
        service = name in SERVICES
        data = struct.pack("<i", class_ids[name]) + _string(name) + bytes([1 if service else 0]) + struct.pack("<I", len(insts))
        data += _ints([i.ref for i in insts], delta=True)
        if service:
            data += bytes([1] * len(insts))
        out += _chunk(b"INST", data)
    for name in sorted(classes):
        insts = classes[name]
        prop_names = sorted({p for i in insts for p in i.props})
        for pname in prop_names:
            kinds = {i.props[pname][0] for i in insts if pname in i.props}
            kind = kinds.pop()
            vals = []
            for i in insts:
                if pname in i.props:
                    vals.append(i.props[pname][1])
                else:
                    vals.append({"string": "", "bool": False, "float": 0.0, "token": 0}[kind])
            data = struct.pack("<i", class_ids[name]) + _string(pname)
            if kind == "string":
                data += bytes([0x01]) + b"".join(_string(v) for v in vals)
            elif kind == "bool":
                data += bytes([0x02]) + bytes(1 if v else 0 for v in vals)
            elif kind == "float":
                data += bytes([0x04]) + _floats(vals)
            elif kind == "token":
                data += bytes([0x12]) + _interleave([struct.pack(">I", v) for v in vals])
            out += _chunk(b"PROP", data)
    data = bytes([0]) + struct.pack("<I", len(order))
    data += _ints([i.ref for i in order], delta=True)
    data += _ints([i.parent.ref if i.parent else -1 for i in order], delta=True)
    out += _chunk(b"PRNT", data)
    out += b"END\x00" + struct.pack("<III", 0, 9, 0) + b"</roblox>"
    with open(path, "wb") as f:
        f.write(out)
    return len(out)
