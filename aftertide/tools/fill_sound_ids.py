#!/usr/bin/env python3
"""Fill src/shared/Config/Sounds.luau with uploaded audio IDs.

Make a text file (e.g. ids.txt) with one line per sound:  Gun_revolver 1234567890
(the name is the .ogg file name without extension; any spacing, ":" or "=" works),
then run:  python3 tools/fill_sound_ids.py ids.txt
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(os.path.dirname(HERE), "src", "shared", "Config", "Sounds.luau")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    ids = {}
    for line in open(sys.argv[1], encoding="utf-8"):
        m = re.match(r"\s*([A-Za-z_]+)\s*[:=\s]\s*(?:rbxassetid://)?(\d+)", line)
        if m:
            ids[m.group(1)] = m.group(2)
    src = open(PATH, encoding="utf-8").read()
    done = 0
    for key, value in ids.items():
        src, n = re.subn(r'(\n\t%s = )"[^"]*"' % re.escape(key), r'\1"rbxassetid://%s"' % value, src)
        done += n
        if n == 0:
            print("unknown sound name:", key)
    open(PATH, "w", encoding="utf-8").write(src)
    print(f"filled {done} sound IDs. Now run: python3 tools/build_place.py")


if __name__ == "__main__":
    main()
