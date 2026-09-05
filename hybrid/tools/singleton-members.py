#!/usr/bin/env python3
"""Check that `Singleton.member` references name something the singleton declares.

qmllint cannot do this here. None of the 49 QML singletons in this tree are
declared in a `qmldir`, so qmllint never resolves the type behind `Colours` or
`Paths`, and every member access on one is unchecked. Proved by injecting
`Colours.paletteXX.m3outlineYY` into a file and watching the gate stay silent at
exit 0 -- three bogus accesses, zero findings.

That matters because it is the most common way to break this codebase: singleton
members are renamed constantly, and a stale reference is silent at load time too.
QML resolves it to `undefined`, and the symptom is a panel that renders blank or
a binding that quietly evaluates to nothing.

Scope, deliberately narrow so that a finding is always real:

  * only the FIRST member of a chain is checked -- `Colours.palette.m3outline`
    checks `palette` on Colours and stops, because resolving `palette`'s type
    means implementing QML's type system;
  * only singletons that are QML files in this repo. `Config`, `Quickshell`,
    `Hypr` and friends are C++ or plugin types, and their members live in headers;
  * a singleton with any `property alias` or nested `id:` fan-out is still
    checked, but base-type members (objectName, children, ...) are allowlisted.

Exit 1 on any reference that resolves to nothing.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Members every QObject/Item carries, which no singleton declares itself.
BASE_MEMBERS = {
    "objectName", "children", "data", "parent", "visible", "enabled", "width",
    "height", "x", "y", "z", "opacity", "state", "states", "transitions",
    "anchors", "implicitWidth", "implicitHeight", "childrenRect", "clip",
    "focus", "activeFocus", "rotation", "scale", "transform", "destroy",
    "toString", "valueOf", "hasOwnProperty", "constructor",
}

# Known-dead references, kept for the same reason dead-qml.py keeps the file they
# live in: they document a gap rather than a mistake of ours.
ALLOWED = {
    ("modules/notifications/QuickSharePrompt.qml", "QuickShare", "hasPendingTransfer"):
        "half-finished in MiDnight. The file is never instantiated and is allowlisted in "
        "dead-qml.py for the same reason -- it is the only incoming-transfer UI that exists, "
        "kept as the design for the gap. Fixing the reference without building the feature "
        "would only hide that. See trap T27.",
}

DECL = re.compile(
    r"^\s*(?:readonly\s+|required\s+|default\s+)*"
    r"(?:property\s+(?:alias\s+|list<[^>]+>\s+|[\w.]+\s+)(\w+)"
    r"|function\s+(\w+)"
    r"|signal\s+(\w+)"
    # `component Foo: QtObject {}` is a nested type, reached as Singleton.Foo.
    r"|component\s+(\w+))",
    re.M,
)

# The root type of the QML document. A singleton whose base we cannot enumerate
# inherits members we cannot see, so every reference to it would be a guess.
ROOT_TYPE = re.compile(r"^([A-Z][\w.]*)\s*\{", re.M)

# Bases whose entire member surface is BASE_MEMBERS, so a singleton on one of
# these is fully enumerable from its own file.
KNOWN_EMPTY_BASES = {"QtObject", "Singleton", "Item"}


def tracked(pattern: str) -> list[Path]:
    out = subprocess.run(
        ["git", "ls-files", pattern], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return [ROOT / p for p in out.stdout.split()]


def declared_members(path: Path) -> set[str]:
    src = path.read_text(encoding="utf-8", errors="replace")
    names: set[str] = set()
    for m in DECL.finditer(src):
        names.update(g for g in m.groups() if g)
    # `signal fooChanged` is implicit for every property.
    names.update(f"{n}Changed" for n in list(names))
    return names


def main() -> int:
    singletons: dict[str, Path] = {}
    for path in tracked("*.qml"):
        head = path.read_text(encoding="utf-8", errors="replace")[:200]
        if "pragma Singleton" in head:
            singletons[path.stem] = path

    # Only check singletons whose members can be fully enumerated. Anything built
    # on a type we cannot read -- Searcher, a plugin type, another fork's base --
    # inherits members that are invisible here, and reporting those as missing
    # would be the checker guessing. Silence beats a false positive: this gate is
    # useless the moment someone learns to ignore its output (T23).
    resolvable: dict[str, set[str]] = {}
    unresolvable: dict[str, str] = {}
    for name, path in singletons.items():
        src = path.read_text(encoding="utf-8", errors="replace")
        m = ROOT_TYPE.search(src)
        base = m.group(1) if m else "?"
        if base in KNOWN_EMPTY_BASES:
            resolvable[name] = declared_members(path) | BASE_MEMBERS
        else:
            unresolvable[name] = base
    members = resolvable

    # `Name.member`, but not `foo.Name.member` and not a declaration of Name itself.
    if not members:
        print("no fully-enumerable singletons; nothing to check")
        return 0
    ref = re.compile(r"(?<![\w.])(" + "|".join(sorted(map(re.escape, members))) + r")\.(\w+)")

    bad: list[tuple[Path, int, str, str]] = []
    allowed: list[tuple[str, str, str]] = []
    checked = 0
    for path in tracked("*.qml"):
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            stripped = line.lstrip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            for m in ref.finditer(line):
                singleton, member = m.group(1), m.group(2)
                # A singleton referring to itself by id, or importing its own name.
                if singletons[singleton] == path:
                    continue
                checked += 1
                if member in members[singleton]:
                    continue
                key = (str(path.relative_to(ROOT)), singleton, member)
                if key in ALLOWED:
                    allowed.append(key)
                    continue
                bad.append((path, lineno, singleton, member))

    rel = lambda p: p.relative_to(ROOT)
    if bad:
        for path, lineno, singleton, member in bad:
            print(f"\033[0;31m[missing]\033[0m {rel(path)}:{lineno}: "
                  f"{singleton}.{member} is not declared in {rel(singletons[singleton])}")
        print()
    print(f"{len(singletons)} singleton(s): {len(members)} fully enumerable, "
          f"{len(unresolvable)} skipped (base type not readable here)")
    if allowed and "--verbose" in sys.argv:
        for f, sing, mem in dict.fromkeys(allowed):
            print(f"  allowed {f}: {sing}.{mem}\n            {ALLOWED[(f, sing, mem)]}")
    print(f"{checked} member reference(s) checked, {len(allowed)} allowlisted, "
          f"{len(bad)} resolving to nothing")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
