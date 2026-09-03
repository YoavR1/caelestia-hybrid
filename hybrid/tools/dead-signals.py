#!/usr/bin/env python3
"""Find Qt signals that are declared but can never be emitted.

    ./hybrid/tools/dead-signals.py            # report; exit 1 if any are found
    ./hybrid/tools/dead-signals.py --verbose  # also show why each live signal is live

This exists because of trap T21. `BeatTracker::beat` was declared, connected to by
modules/dashboard/dash/MediaShapes.qml, and emitted by nothing -- in all three upstreams.
No gate could see it: a QML `Connections` handler for a declared signal is valid QML, so
qmllint resolves it and has nothing to say, and a signal with no emitter is valid C++,
because moc generates a perfectly good emitter that simply never gets called.

The checker is deliberately generous about what counts as an emitter, because a false
positive here costs more than a miss -- it sends someone to "fix" working code. A signal is
live if any of these hold:

  * it is the NOTIFY of a MEMBER or WRITE property, which moc emits on write;
  * `&Class::signal` appears anywhere, which covers signal-to-signal forwarding;
  * `emit signal(` appears in a member function of the class *or of any class that derives
    from it*, since a subclass emitting a base's signal is ordinary;
  * the class forwards signals through the runtime metaobject API (`notifySignal()`),
    which no source scan can follow.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "plugin" / "src"
VERBOSE = "--verbose" in sys.argv


def parse():
    headers = sorted(SRC.rglob("*.hpp"))
    sources = sorted(SRC.rglob("*.cpp"))
    text = {p: p.read_text() for p in headers + sources}

    classes = {}
    for header in headers:
        cls = None
        in_signals = False
        for lineno, line in enumerate(text[header].split("\n"), 1):
            decl = re.match(r"\s*class\s+(\w+)\s*(?:final\s*)?(?::([^{]*))?\{?", line)
            if decl and ("{" in line or ":" in line):
                cls = decl.group(1)
                bases = re.findall(r"(?:public|protected|private)\s+(?:\w+::)*(\w+)", decl.group(2) or "")
                classes.setdefault(cls, {"file": header, "signals": [], "auto": set(), "bases": bases})
                in_signals = False
            if cls is None:
                continue
            prop = re.search(r"Q_PROPERTY\s*\(.*?\b(?:MEMBER|WRITE)\b.*?NOTIFY\s+(\w+)", line)
            if prop:
                classes[cls]["auto"].add(prop.group(1))
            if re.match(r"\s*(signals|Q_SIGNALS)\s*:", line):
                in_signals = True
                continue
            if re.match(r"\s*(public|private|protected)\s*(slots|Q_SLOTS)?\s*:", line):
                in_signals = False
            if in_signals:
                sig = re.match(r"\s*(?:\[\[[^\]]*\]\]\s*)*void\s+(\w+)\s*\(", line)
                if sig:
                    classes[cls]["signals"].append((sig.group(1), lineno))
    return classes, "\n".join(text.values()), text


def main():
    classes, body, text = parse()

    # class -> every class that is it or derives from it, so a subclass emit counts
    def family(cls):
        out = {cls}
        changed = True
        while changed:
            changed = False
            for name, info in classes.items():
                if name not in out and out & set(info["bases"]):
                    out.add(name)
                    changed = True
        return out

    # a class whose implementation forwards signals through the metaobject API
    meta_forward = {
        cls for cls, info in classes.items()
        if any("notifySignal()" in t for p, t in text.items() if p.stem == info["file"].stem)
    }

    emits = {}   # class-scope -> set of signal names emitted inside it
    for match in re.finditer(r"\b(?:emit|Q_EMIT)\s+(?:\w+(?:->|\.))?(\w+)\s*\(", body):
        starts = {cls: body.rfind("\n" + cls + "::", 0, match.start()) for cls in classes}
        owner = max(starts, key=lambda c: starts[c])
        if starts[owner] >= 0:
            emits.setdefault(owner, set()).add(match.group(1))

    dead, total = [], 0
    for cls in sorted(classes):
        kin = family(cls)
        for sig, lineno in classes[cls]["signals"]:
            total += 1
            if sig in classes[cls]["auto"]:
                why = "moc emits it (MEMBER/WRITE property)"
            elif re.search(rf"&\s*(?:\w+::)*{cls}::{sig}\b", body):
                why = f"used as &{cls}::{sig}"
            elif any(sig in emits.get(k, ()) for k in kin):
                who = next(k for k in kin if sig in emits.get(k, ()))
                why = f"emitted in {who}::"
            elif cls in meta_forward:
                why = "metaobject notifySignal() forwarding"
            else:
                dead.append((cls, sig, classes[cls]["file"], lineno))
                continue
            if VERBOSE:
                print(f"  ok   {cls}::{sig}".ljust(56), why)

    for cls, sig, path, lineno in dead:
        rel = path.relative_to(ROOT)
        print(f"  DEAD {cls}::{sig}".ljust(56), f"{rel}:{lineno}")

    print(f"\n{total} signal(s) checked, {len(dead)} with no reachable emitter")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
