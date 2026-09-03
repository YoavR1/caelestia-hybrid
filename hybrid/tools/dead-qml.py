#!/usr/bin/env python3
"""Find QML files no other file instantiates.

    ./hybrid/tools/dead-qml.py            # report; exit 1 if any are found
    ./hybrid/tools/dead-qml.py --verbose  # also list the allowlisted files

A merge-heavy tree accumulates superseded components: the replacement lands, the call site
moves to it, and the old file stays because nothing complains. Three were found this way --
an earlier video-wallpaper component whose logic now lives in Wallpaper.qml plus
WallpaperPauser, a Bad Apple controller superseded by BadApplePlayer, and 27 lines of debug
scaffolding that pops a red window. All three were dead in MiDnight too, so this is not a
merge regression; it is inherited.

Two things this has to get right, both of which it got wrong first:

  * A QML type is referenced as `Type` **or** as `Namespace.Type`. Treating a leading dot as
    disqualifying -- reasonable, to skip property accesses -- makes every namespaced use
    invisible, and `BarPopouts.ClipWrapper` looked dead when it is not.
  * A file being unused *here* does not make it ours to delete. `components/misc/Ref.qml` is
    unused in all three upstreams, including upstream itself, because the C++ ServiceRef
    replaced it. Deleting it would trade eight dead lines for a delete/modify conflict every
    time upstream touches the file.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERBOSE = "--verbose" in sys.argv

ALLOWED = {
    "components/misc/Ref.qml":
        "upstream's own leftover -- unused there too, superseded by the C++ ServiceRef. "
        "Upstream's to delete; removing it here only buys a merge conflict.",
    "modules/notifications/QuickSharePrompt.qml":
        "the only incoming-transfer UI that exists. Never instantiated, and it writes to a "
        "QuickShare.hasPendingTransfer that no one defines -- half-finished in MiDnight, not "
        "broken by us. Kept as the design for the gap rather than deleted. See trap T27.",
}


def main():
    files = subprocess.run(["git", "-C", str(ROOT), "ls-files", "*.qml"],
                           capture_output=True, text=True).stdout.split()
    texts = {f: (ROOT / f).read_text() for f in files}
    others = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "*.cpp", "*.hpp", "CMakeLists.txt", "*.json", "qmldir"],
        capture_output=True, text=True).stdout.split()
    outside = "\n".join((ROOT / f).read_text(errors="ignore") for f in others)

    dead, skipped = [], []
    for f in files:
        stem = Path(f).stem
        if stem == "shell":                       # the entry point
            continue
        rest = "\n".join(t for g, t in texts.items() if g != f)
        # no lookbehind on `.` -- a namespaced `Namespace.Type` is a real reference
        if re.search(rf'(?<![\w]){stem}(?![\w])', rest) or re.search(rf'(?<![\w]){stem}(?![\w])', outside):
            continue
        (skipped if f in ALLOWED else dead).append(f)

    for f in skipped:
        if VERBOSE:
            print(f"  allowed {f}\n            {ALLOWED[f]}")

    for f in dead:
        print(f"  DEAD    {f}  ({len(texts[f].splitlines())} lines)")

    print(f"\n{len(files)} QML file(s), {len(skipped)} allowlisted, {len(dead)} unreferenced")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
