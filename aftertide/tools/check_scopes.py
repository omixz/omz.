#!/usr/bin/env python3
"""Finds names used where no local of that name is in scope (and that aren't Roblox/Luau
globals). In Roblox such a name silently reads nil, so one slip stops a whole script.
  python3 tools/check_scopes.py            # all files under src/
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src")
GLOBALS = set("""
game workspace script plugin shared Enum Vector3 Vector2 CFrame Color3 UDim UDim2 Instance Ray RaycastParams
OverlapParams NumberSequence NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint NumberRange Rect Region3
TweenInfo BrickColor PhysicalProperties Random DateTime Font Axes Faces PathWaypoint Content buffer utf8 bit32
math string table task coroutine debug os typeof type typeof require print warn error assert pcall xpcall select
pairs ipairs next tostring tonumber rawget rawset rawequal rawlen setmetatable getmetatable unpack tick time wait
delay spawn settings UserSettings _G _VERSION newproxy gcinfo elapsedTime collectgarbage loadstring
self true false nil and or not
""".split())
KEYWORDS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while continue".split())

TOKEN = re.compile(r"""
  (?P<comment>--\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|--[^\n]*)
 |(?P<lstr>\[(?P<seq>=*)\[.*?\](?P=seq)\])
 |(?P<str>"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'|`(?:\\.|[^`\\])*`)
 |(?P<num>0[xX][0-9a-fA-F_]+|\d[\d_]*(?:\.\d*)?(?:[eE][+-]?\d+)?|\.\d+)
 |(?P<name>[A-Za-z_][A-Za-z0-9_]*)
 |(?P<op>\.\.\.|\.\.=|\.\.|==|~=|<=|>=|\+=|-=|\*=|/=|//=|%=|\^=|->|::|[-+*/%^#<>=(){}\[\];:,.])
 |(?P<ws>\s+)
""", re.S | re.X)


def tokens(src):
    out, pos, line = [], 0, 1
    while pos < len(src):
        m = TOKEN.match(src, pos)
        if not m:
            pos += 1
            continue
        kind = m.lastgroup
        text = m.group(0)
        if kind in ("name", "op", "num", "str", "lstr"):
            out.append((kind if kind != "lstr" else "str", text, line))
        line += text.count("\n")
        pos = m.end()
    return out


def check(path):
    src = open(path, encoding="utf-8").read()
    toks = tokens(src)
    scopes = [set()]
    problems = []
    brackets = []  # stack of '(' '{' '['
    pending_for = None
    pending_func = None  # params waiting for the function body
    i = 0
    n = len(toks)

    def declared(name):
        return any(name in s for s in scopes)

    while i < n:
        kind, text, line = toks[i]
        prev = toks[i - 1][1] if i > 0 else ""
        nxt = toks[i + 1][1] if i + 1 < n else ""
        if kind == "op":
            if text in "({[":
                brackets.append(text)
            elif text in ")}]":
                if brackets:
                    brackets.pop()
                if text == ")" and pending_func is not None and pending_func[0] == len(brackets):
                    scopes.append(set(pending_func[1]))
                    pending_func = None
            i += 1
            continue
        if kind != "name":
            i += 1
            continue
        if text == "function":
            # function [a.b:c](params) body end  /  local function f(...)
            j = i + 1
            names = []
            method = False
            while j < n and toks[j][1] != "(":
                if toks[j][1] == ":":
                    method = True
                if toks[j][0] == "name":
                    names.append(toks[j][1])
                j += 1
            if names and prev != "local" and not declared(names[0]) and names[0] not in GLOBALS:
                problems.append((line, names[0]))
            params = ["self"] if method else []
            k = j + 1
            while k < n and toks[k][1] != ")":
                if toks[k][0] == "name":
                    params.append(toks[k][1])
                elif toks[k][1] == "...":
                    params.append("...")
                k += 1
            if prev == "local" and names:
                scopes[-1].add(names[0])
            scopes.append(set(params))  # the body scope, closed by its `end`
            i = k + 1
            continue
        if text == "local":
            j = i + 1
            if j < n and toks[j][1] == "function":
                i += 1
                continue
            new = []
            while j < n:
                if toks[j][0] == "name" and toks[j][1] not in KEYWORDS:
                    new.append(toks[j][1])
                    j += 1
                    if j < n and toks[j][1] == ":":  # type annotation
                        j += 2
                    if j < n and toks[j][1] == ",":
                        j += 1
                        continue
                break
            # the initialiser is evaluated before the names exist
            k = j
            if k < n and toks[k][1] == "=":
                scopes[-1].update(())
            scopes[-1].update(new)
            i = j
            continue
        if text == "for":
            j = i + 1
            names = []
            while j < n and toks[j][1] not in ("in", "="):
                if toks[j][0] == "name":
                    names.append(toks[j][1])
                j += 1
            pending_for = names
            i = j
            continue
        if text in ("do",):
            scopes.append(set(pending_for or []))
            pending_for = None
            i += 1
            continue
        if text in ("then", "repeat"):
            scopes.append(set())
            i += 1
            continue
        if text in ("else", "elseif"):
            if len(scopes) > 1:
                scopes.pop()
            if text == "else":
                scopes.append(set())
            i += 1
            continue
        if text in ("end", "until"):
            if len(scopes) > 1:
                scopes.pop()
            i += 1
            continue
        if text in KEYWORDS:
            i += 1
            continue
        if prev in (".", ":", "::") or (prev == "->"):
            i += 1
            continue
        # table constructor key: { name = value }
        if nxt == "=" and brackets and brackets[-1] == "{" and prev in ("{", ",", ";"):
            i += 1
            continue
        if not declared(text) and text not in GLOBALS:
            problems.append((line, text))
        i += 1
    return problems


def main():
    bad = 0
    for dirpath, _, files in os.walk(ROOT):
        for f in sorted(files):
            if f.endswith(".luau"):
                path = os.path.join(dirpath, f)
                for line, name in check(path):
                    bad += 1
                    print(f"{os.path.relpath(path, ROOT)}:{line}: '{name}' is not defined here")
    print("OK: no undefined names" if bad == 0 else f"{bad} undefined name(s)")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
