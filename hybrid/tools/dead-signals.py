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


def parse(src=None):
    src = src or SRC
    headers = sorted(src.rglob("*.hpp"))
    sources = sorted(src.rglob("*.cpp"))
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
    # Emit and reference matching runs over the joined text, and a commented-out
    # `emit foo();` matched it -- so commenting out the last emitter left the
    # signal reported as live, which is precisely the regression this checker
    # exists to catch. Strip comments for that search only: the line-by-line
    # parse above keeps the original text so reported line numbers stay true.
    return classes, strip_comments("\n".join(text.values())), text


# String literals are matched first and kept, so a "https://..." inside one is
# not mistaken for a line comment.
_COMMENTS = re.compile(r"""("(?:\\.|[^"\\])*")|('(?:\\.|[^'\\])*')|/\*.*?\*/|//[^\n]*""", re.S)


def strip_comments(src: str) -> str:
    def keep_strings(m: re.Match) -> str:
        tok = m.group(0)
        if tok.startswith(('"', "'")):
            return tok
        # Preserve newlines so offsets stay roughly aligned for the ownership scan.
        return "\n" * tok.count("\n")

    return _COMMENTS.sub(keep_strings, src)


def self_test() -> int:
    """Prove the detector still detects, against fixtures shaped like this codebase.

    A checker that has silently stopped working reports zero and passes, which is
    indistinguishable from a clean tree (T23). This one was validated by hand when
    it was written and by nothing since.

    The fixtures matter more than usual here. Member definitions in this tree read
    `void Class::method()`, so the only line that actually starts with `Class::` is
    normally the constructor -- and that is the anchor the emit-ownership heuristic
    uses. A fixture without one would not exercise the real path.
    """
    import tempfile

    HDR = """#pragma once
#include <QObject>

class Probe : public QObject {{
    Q_OBJECT
{prop}
public:
    explicit Probe(QObject* parent = nullptr);
    void doThing();

signals:
    void fired();
}};
"""
    SRC_TMPL = """#include "probe.hpp"

Probe::Probe(QObject* parent)
    : QObject(parent) {{}}

void Probe::doThing() {{
{body}
}}
"""

    cases = [
        ("no emitter at all", "", "    return;", True),
        ("emitted in its own class", "", "    emit fired();", False),
        ("used as &Probe::fired", "", "    connect(this, &Probe::fired, this, []{});", False),
        ("Q_PROPERTY MEMBER NOTIFY",
         "    Q_PROPERTY(int n MEMBER m_n NOTIFY fired)", "    return;", False),
        # Commenting out the last emitter is one of the likeliest ways a signal
        # actually dies, and it read as live until comments were stripped.
        ("emit behind a line comment", "", "    // emit fired();", True),
        ("emit behind a block comment", "", "    /* emit fired(); */", True),
        # A string containing // must not be mistaken for a comment and eat the
        # emit that follows it on the same line.
        ("emit after a url in a string", "",
         '    qDebug() << "see https://example.com/x"; emit fired();', False),
    ]

    failures = 0
    for name, prop, body, expect_dead in cases:
        with tempfile.TemporaryDirectory() as td:
            d = Path(td)
            (d / "probe.hpp").write_text(HDR.format(prop=prop))
            (d / "probe.cpp").write_text(SRC_TMPL.format(body=body))
            classes, joined, text = parse(d)
            if "Probe" not in classes or not classes["Probe"]["signals"]:
                failures += 1
                print(f"  \033[0;31m{name}\033[0m: fixture parsed no signal at all")
                continue
            import io, contextlib
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                rc = main(d)
            got_dead = rc == 1
            if got_dead != expect_dead:
                failures += 1
                verb = "should have been reported dead" if expect_dead else "should have been live"
                print(f"  \033[0;31m{name}\033[0m: Probe::fired {verb}")

    # A subclass emitting a base's signal counts, which needs two headers.
    with tempfile.TemporaryDirectory() as td:
        d = Path(td)
        (d / "probe.hpp").write_text(HDR.format(prop=""))
        (d / "derived.hpp").write_text("""#pragma once
#include "probe.hpp"

class Derived : public Probe {
    Q_OBJECT
public:
    explicit Derived(QObject* parent = nullptr);
    void go();
};
""")
        (d / "probe.cpp").write_text(SRC_TMPL.format(body="    return;"))
        (d / "derived.cpp").write_text("""#include "derived.hpp"

Derived::Derived(QObject* parent)
    : Probe(parent) {}

void Derived::go() {
    emit fired();
}
""")
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            rc = main(d)
        if rc != 0:
            failures += 1
            print("  \033[0;31msubclass emit\033[0m: a base signal emitted by a subclass "
                  "should count as live")

    total = len(cases) + 1
    if failures:
        print(f"\033[1;31mFAIL\033[0m self-test: {failures} of {total} case(s) wrong")
        return 1
    print(f"\033[1;32mPASS\033[0m self-test: {total} cases, detector finds the dead signal "
          "and clears every live one")
    return 0


def main(src=None):
    classes, body, text = parse(src)

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
        # Fixture paths in the self-test are outside the repo.
        rel = path.relative_to(ROOT) if path.is_relative_to(ROOT) else path
        print(f"  DEAD {cls}::{sig}".ljust(56), f"{rel}:{lineno}")

    print(f"\n{total} signal(s) checked, {len(dead)} with no reachable emitter")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
