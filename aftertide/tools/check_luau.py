#!/usr/bin/env python3
"""Lightweight static checks for the AFTERTIDE Luau sources (no Roblox tooling required).

* block balance (function/if/for/while/do/repeat ... end/until)
* bracket balance ( ) [ ] { }
* cross-module calls: Services.X.fn / Controllers.X.fn must exist in module X
* string-key config lookups are not checked (use luau-lsp for full type checking)

Usage: python3 tools/check_luau.py [src_dir]
"""
import os
import re
import sys

KEYWORDS_OPEN = {"function", "if", "do", "repeat"}


def tokenize(src):
    """Yield (kind, value, line) skipping comments and strings."""
    i, n, line = 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                if j < 0:
                    yield ("error", "unterminated long comment", line)
                    return
                line += src.count("\n", i, j)
                i = j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = re.match(r"\[(=*)\[", src[i:])
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            if j < 0:
                yield ("error", "unterminated long string", line)
                return
            line += src.count("\n", i, j)
            i = j + len(close)
            yield ("string", "", line)
            continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                if src[j] == "\n":
                    yield ("error", "newline in string", line)
                    break
                j += 1
            i = j + 1
            yield ("string", "", line)
            continue
        if c == "`":
            j = i + 1
            depth = 0
            while j < n:
                if src[j] == "\\":
                    j += 2
                    continue
                if src[j] == "{":
                    depth += 1
                elif src[j] == "}":
                    depth -= 1
                elif src[j] == "`" and depth == 0:
                    break
                j += 1
            i = j + 1
            yield ("string", "", line)
            continue
        if c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
            word = m.group(0)
            # attribute access like foo.end is impossible in Lua, but .do/.repeat can't occur either
            prev = src[i - 1] if i > 0 else ""
            yield ("name" if prev in ".:" else "word", word, line)
            i += len(word)
            continue
        if c in "()[]{}":
            yield ("bracket", c, line)
            i += 1
            continue
        i += 1


def check_blocks(path, src):
    errors = []
    stack = []
    brackets = []
    pending_do = 0
    pairs = {")": "(", "]": "[", "}": "{"}
    for kind, value, line in tokenize(src):
        if kind == "error":
            errors.append(f"{path}:{line}: {value}")
        elif kind == "bracket":
            if value in "([{":
                brackets.append((value, line))
            else:
                if not brackets or brackets[-1][0] != pairs[value]:
                    errors.append(f"{path}:{line}: unbalanced '{value}'")
                    return errors
                brackets.pop()
        elif kind == "word":
            if value in ("for", "while"):
                stack.append((value, line))
                pending_do += 1
            elif value == "do":
                if pending_do:
                    pending_do -= 1
                else:
                    stack.append(("do", line))
            elif value in ("function", "if", "repeat"):
                stack.append((value, line))
            elif value == "end":
                if not stack or stack[-1][0] == "repeat":
                    errors.append(f"{path}:{line}: unexpected 'end'")
                    return errors
                stack.pop()
            elif value == "until":
                if not stack or stack[-1][0] != "repeat":
                    errors.append(f"{path}:{line}: unexpected 'until'")
                    return errors
                stack.pop()
    for opener, line in stack:
        errors.append(f"{path}:{line}: '{opener}' never closed")
    for b, line in brackets:
        errors.append(f"{path}:{line}: '{b}' never closed")
    return errors


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "src")
    files = {}
    for dirpath, _, names in os.walk(root):
        for name in names:
            if name.endswith(".luau"):
                files[os.path.join(dirpath, name)] = open(os.path.join(dirpath, name), encoding="utf-8").read()

    errors = []
    for path, src in files.items():
        errors += check_blocks(os.path.relpath(path, root), src)

    # module -> defined functions/fields
    defined = {}
    for path, src in files.items():
        mod = os.path.basename(path).split(".")[0]
        names = set(re.findall(r"^function\s+%s[.:](\w+)" % re.escape(mod), src, re.M))
        names |= set(re.findall(r"^%s\.(\w+)\s*=" % re.escape(mod), src, re.M))
        defined[mod] = names

    for path, src in files.items():
        for registry in ("Services", "Controllers"):
            for mod, fn in re.findall(r"\b%s\.(\w+)\.(\w+)" % registry, src):
                if mod not in defined:
                    errors.append(f"{os.path.relpath(path, root)}: unknown module {registry}.{mod}")
                elif fn not in defined[mod]:
                    errors.append(f"{os.path.relpath(path, root)}: {registry}.{mod}.{fn} is not defined in {mod}")

    if errors:
        print("\n".join(errors))
        sys.exit(1)
    print(f"OK: {len(files)} Luau files, blocks/brackets balanced, cross-module calls resolve")


if __name__ == "__main__":
    main()
