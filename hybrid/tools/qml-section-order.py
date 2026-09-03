#!/usr/bin/env python3
"""Reorder QML object members into the section order upstream's conventions checker wants.

`scripts/qml-lint-conventions.py` reports `section-order` violations but has no --fix for
them, and there were 498 of them across 65 files in the MiDnight baseline. This is the
missing fixer.

    ./hybrid/tools/qml-section-order.py                 # rewrite every file
    ./hybrid/tools/qml-section-order.py --dry-run       # report what would move
    ./hybrid/tools/qml-section-order.py modules/bar     # a subset (files or dirs)

Three things make this safe enough to run in bulk:

  * It classifies members with the checker's own `classify_line`, imported rather than
    reimplemented, so the two cannot drift.
  * It only ever moves whole lines within one object body. The multiset of non-blank lines
    in a file is invariant, and that is asserted before anything is written -- a bug in
    block extraction cannot silently drop or duplicate code, only produce something that
    fails to parse.
  * A body that is already in order is returned byte-for-byte unchanged, so the diff stays
    confined to the bodies that actually violate.

It relies on the tree being qmlformat-clean: member boundaries are found by indentation,
which is only trustworthy after `qmlformat -i`. Run the formatter first, and again after.

QML declaration order is not semantically meaningful, with one exception: children in the
default property list are ordered. The sort is stable, so their relative order is preserved.
"""

import importlib.util
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent

_spec = importlib.util.spec_from_file_location(
    "qml_conventions", ROOT / "scripts" / "qml-lint-conventions.py"
)
_conv = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_conv)

Section = _conv.Section
COMMENT_LINE_RE = _conv.COMMENT_LINE_RE

# The checker returns None for attached-property bindings -- `Layout.fillWidth: true`,
# `WlrLayershell.exclusionMode: ...`, `Config.screen: ...` -- because BINDING_RE wants a
# lowercase start and ATTACHED_HANDLER_RE only covers `on`-prefixed signal handlers. They
# are invisible to it, but they are real members and there are over 900 of them. Sort them
# as bindings: that is what they are, and the checker cannot object to where they land.
ATTACHED_PROPERTY_RE = re.compile(r"^[A-Z]\w*(?:\.\w+)+\s*:")

RED = "\033[0;31m"
YELLOW = "\033[0;33m"
BOLD = "\033[1m"
RESET = "\033[0m"


def classify(stripped: str):
    section = _conv.classify_line(stripped)
    if section is None and ATTACHED_PROPERTY_RE.match(stripped):
        return Section.BINDING
    return section


class Member:
    """One member of a QML object body: its comments, its lines, and what section it is."""

    def __init__(self, comments, lines, section, blank_before):
        self.comments = comments
        self.lines = lines
        self.section = section
        self.blank_before = blank_before

    @property
    def multiline(self) -> bool:
        return len(self.lines) > 1 or bool(self.comments)

    def emit(self) -> list[str]:
        return self.comments + self.lines


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def opens_scope(first: str) -> bool:
    """Does this member's first line open a brace that stays open past it?"""
    return first.count("{") - first.count("}") > 0


def recurse_into(section, first: str) -> bool:
    """Mirror the checker's skip rules: a JS body is not QML structure."""
    if not opens_scope(first):
        return False
    if section == Section.FUNCTION:
        return False
    if section == Section.BINDING:
        after = first[first.index(":") + 1 :].strip()
        return bool(after) and after[0].isupper()
    return True


def split_members(lines, start, end, indent):
    """Split lines[start:end] -- one object body at `indent` -- into Members.

    Returns (members, ok). `ok` is False if any member could not be classified, in which
    case the caller must not reorder this body.
    """
    members = []
    pending = []
    blank = False
    in_block_comment = False
    i = start
    ok = True

    while i < end:
        line = lines[i]
        stripped = line.strip()

        if in_block_comment:
            pending.append(line)
            if "*/" in stripped:
                in_block_comment = False
            i += 1
            continue

        if not stripped:
            blank = True
            i += 1
            continue

        if COMMENT_LINE_RE.match(stripped):
            pending.append(line)
            i += 1
            continue

        if stripped.startswith("/*"):
            # A commented-out block can contain anything, including lines that look like
            # members. Swallow it whole rather than parsing its contents.
            pending.append(line)
            in_block_comment = "*/" not in stripped
            i += 1
            continue

        if indent_of(line) != indent:
            return [], False  # not shaped the way qmlformat leaves things

        # Consume this member: every following line that is blank or more-indented, plus
        # lines back at our own indent that close it (`}`, `]`, `})`, ...).
        j = i
        while True:
            k = j + 1
            while k < end and (not lines[k].strip() or indent_of(lines[k]) > indent):
                k += 1
            j = k - 1
            if k < end and indent_of(lines[k]) == indent and lines[k].strip()[0] in "}])":
                j = k
                continue
            break

        body = lines[i : j + 1]
        while body and not body[-1].strip():
            body.pop()  # trailing blanks are separators, not part of the member

        section = classify(stripped)
        if section is None:
            ok = False

        members.append(Member(pending, body, section, blank))
        pending, blank = [], False
        i += len(body)

    if pending:
        # A comment with nothing under it. Pin the body rather than move it somewhere.
        members.append(Member([], pending, Section.COMPONENT_DEF, blank))
        ok = False

    return members, ok


def join(members, indent: int) -> list[str]:
    """Emit members, with a blank line wherever the conventions or the original had one."""
    out = []
    for idx, m in enumerate(members):
        if idx:
            prev = members[idx - 1]
            if prev.section != m.section or prev.multiline or m.multiline or m.blank_before:
                out.append("")
        out.extend(m.emit())
    return out


def process_body(lines, start, end, indent, stats) -> list[str]:
    """Reorder one object body, recursing into nested QML objects first."""
    members, ok = split_members(lines, start, end, indent)
    if not members:
        return lines[start:end]

    changed = False
    for m in members:
        if recurse_into(m.section, m.lines[0].strip()):
            inner = process_body(m.lines, 1, len(m.lines) - 1, indent + 4, stats)
            if inner != m.lines[1:-1]:
                m.lines = [m.lines[0]] + inner + [m.lines[-1]]
                changed = True

    if not ok:
        stats["unclassified"] += 1
    else:
        order = sorted(range(len(members)), key=lambda n: (members[n].section, n))
        if order != list(range(len(members))):
            stats["reordered"] += 1
            return join([members[n] for n in order], indent)

    # Nothing moved at this level: keep the original text so the diff stays minimal.
    return join(members, indent) if changed else lines[start:end]


def find_root(lines):
    """Locate the root object body: (first body line, index of its closing brace)."""
    for i, line in enumerate(lines):
        s = line.strip()
        if not s or s.startswith(("//", "import ", "pragma ", "/*", "*")):
            continue
        if indent_of(line) == 0 and s.endswith("{"):
            for j in range(len(lines) - 1, i, -1):
                if lines[j].rstrip() == "}":
                    return i + 1, j
        return None
    return None


def process_file(path: Path, stats: dict, dry_run: bool) -> bool:
    original = path.read_text()
    lines = original.splitlines()
    root = find_root(lines)
    if root is None:
        stats["skipped"].append(str(path.relative_to(ROOT)))
        return False

    start, close = root
    new = lines[:start] + process_body(lines, start, close, 4, stats) + lines[close:]

    def content(ls):
        return sorted(l.strip() for l in ls if l.strip())

    if content(new) != content(lines):
        print(f"{RED}LINE MULTISET CHANGED{RESET} {path} -- refusing to write", file=sys.stderr)
        stats["broken"].append(str(path.relative_to(ROOT)))
        return False

    text = "\n".join(new) + "\n"
    if text == original:
        return False
    if not dry_run:
        path.write_text(text)
    return True


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    dry_run = "--dry-run" in sys.argv or "-n" in sys.argv

    if args:
        targets = []
        for a in args:
            p = Path(a)
            targets.extend(sorted(p.rglob("*.qml")) if p.is_dir() else [p])
    else:
        targets = sorted(p for p in ROOT.rglob("*.qml") if "build" not in p.parts)

    stats = {"reordered": 0, "unclassified": 0, "skipped": [], "broken": []}
    changed = [p for p in targets if process_file(p, stats, dry_run)]

    verb = "would rewrite" if dry_run else "rewrote"
    print(f"{BOLD}{verb} {len(changed)} of {len(targets)} file(s){RESET}")
    print(f"  {stats['reordered']} body/bodies reordered")
    if stats["unclassified"]:
        print(f"  {YELLOW}{stats['unclassified']}{RESET} body/bodies pinned (unclassifiable member)")
    if stats["skipped"]:
        print(f"  {YELLOW}{len(stats['skipped'])}{RESET} file(s) with no single root object, skipped")
    if stats["broken"]:
        print(f"  {RED}{len(stats['broken'])}{RESET} file(s) refused: " + ", ".join(stats["broken"]))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
