#!/usr/bin/env python3
"""Builds build/Aftertide.rbxlx from src/ without Rojo.

Mirrors default.project.json:
  src/shared  -> ReplicatedStorage.Shared
  src/server  -> ServerScriptService.Server
  src/client  -> StarterPlayer.StarterPlayerScripts.Client
File rules (same as Rojo): *.server.luau = Script, *.client.luau = LocalScript, *.luau = ModuleScript,
folders = Folder.

Usage: python3 tools/build_place.py
Then open build/Aftertide.rbxlx in Roblox Studio (File > Open from File).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "build", "Aftertide.rbxlx")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(class_name, name, props="", children=""):
    return (
        f'<Item class="{class_name}" referent="{ref()}"><Properties>'
        f'<string name="Name">{name}</string>{props}</Properties>{children}</Item>\n'
    )


def script_item(path):
    base = os.path.basename(path)
    if base.endswith(".server.luau"):
        cls, name = "Script", base[: -len(".server.luau")]
    elif base.endswith(".client.luau"):
        cls, name = "LocalScript", base[: -len(".client.luau")]
    else:
        cls, name = "ModuleScript", base[: -len(".luau")]
    with open(path, encoding="utf-8") as f:
        source = f.read()
    return item(cls, name, f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')


def folder_children(directory):
    out = []
    for entry in sorted(os.listdir(directory)):
        full = os.path.join(directory, entry)
        if os.path.isdir(full):
            out.append(item("Folder", entry, "", folder_children(full)))
        elif entry.endswith(".luau"):
            out.append(script_item(full))
    return "".join(out)


def folder(name, directory):
    return item("Folder", name, "", folder_children(directory))


def tree_folder(name, directory):
    from rbxl import Inst
    kids = []
    for entry in sorted(os.listdir(directory)):
        full = os.path.join(directory, entry)
        if os.path.isdir(full):
            kids.append(tree_folder(entry, full))
        elif entry.endswith(".luau"):
            if entry.endswith(".server.luau"):
                cls, nm = "Script", entry[: -len(".server.luau")]
            elif entry.endswith(".client.luau"):
                cls, nm = "LocalScript", entry[: -len(".client.luau")]
            else:
                cls, nm = "ModuleScript", entry[: -len(".luau")]
            kids.append(Inst(cls, nm, {"Source": ("string", open(full, encoding="utf-8").read())}))
    return Inst("Folder", name, None, kids)


def write_binary(path):
    from rbxl import Inst, write
    roots = [
        Inst("Workspace", "Workspace", {"StreamingEnabled": ("bool", False)}, [Inst("Terrain", "Terrain", {"Decoration": ("bool", True)})]),
        Inst("Lighting", "Lighting", {"Technology": ("token", 4)}),
        Inst("Players", "Players", {"CharacterAutoLoads": ("bool", False)}),
        Inst("ReplicatedStorage", "ReplicatedStorage", None, [tree_folder("Shared", os.path.join(SRC, "shared"))]),
        Inst("ServerScriptService", "ServerScriptService", None, [tree_folder("Server", os.path.join(SRC, "server"))]),
        Inst("StarterPlayer", "StarterPlayer", {"EnableMouseLockOption": ("bool", False), "LoadCharacterAppearance": ("bool", False), "CharacterJumpPower": ("float", 0.0)},
             [Inst("StarterPlayerScripts", "StarterPlayerScripts", None, [tree_folder("Client", os.path.join(SRC, "client"))])]),
    ]
    return write(roots, path)


def main():
    body = "".join(
        [
            item(
                "Workspace",
                "Workspace",
                '<bool name="StreamingEnabled">false</bool>',
                item("Terrain", "Terrain", '<bool name="Decoration">true</bool>'),  # animated grass blades
            ),
            item("Lighting", "Lighting", '<token name="Technology">4</token>'),
            item("Players", "Players", '<bool name="CharacterAutoLoads">false</bool>'),
            item("ReplicatedStorage", "ReplicatedStorage", "", folder("Shared", os.path.join(SRC, "shared"))),
            item("ServerScriptService", "ServerScriptService", "", folder("Server", os.path.join(SRC, "server"))),
            item(
                "StarterPlayer",
                "StarterPlayer",
                '<bool name="EnableMouseLockOption">false</bool>'
                '<bool name="LoadCharacterAppearance">false</bool>'
                '<float name="CharacterJumpPower">0</float>',
                item("StarterPlayerScripts", "StarterPlayerScripts", "", folder("Client", os.path.join(SRC, "client"))),
            ),
        ]
    )
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        + body
        + "</roblox>\n"
    )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"Wrote {os.path.relpath(OUT, ROOT)} ({len(xml) // 1024} KB)")
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    binary = OUT[: -len(".rbxlx")] + ".rbxl"
    size = write_binary(binary)
    print(f"Wrote {os.path.relpath(binary, ROOT)} ({size // 1024} KB, binary: used for Open Cloud publishing)")


if __name__ == "__main__":
    main()
