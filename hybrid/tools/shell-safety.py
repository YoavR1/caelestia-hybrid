#!/usr/bin/env python3
"""Find shell commands whose script string is built from a value.

    ./hybrid/tools/shell-safety.py            # report; exit 1 if any are found
    ./hybrid/tools/shell-safety.py --verbose  # also list the allowlisted sites

`Process.command` and `Quickshell.execDetached` take an argv list, so the shell is usually
unnecessary. When one is used, the script must be a constant and the values must arrive as
positional arguments:

    ["sh", "-c", 'mkdir -p "$1" && cliphist decode "$2" > "$3"', "sh", dir, id, path]

Concatenating or interpolating into the script instead puts the value into shell *syntax*.
Quoting it inside the string is not a fix: a `'` in the value closes the quote and the rest
runs. Ten sites in this tree were written that way, two of them interpolating a URL taken
straight from an HTTP response. See trap T26.

Some shells are the feature rather than a bug, so the allowlist below is explicit and each
entry says why. It is keyed by file and by a snippet of the line, not by line number, so it
does not rot every time something above it moves.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERBOSE = "--verbose" in sys.argv

# (file, snippet that must appear in the flagged line, why it is allowed)
ALLOWED = [
    ("modules/launcher/services/Keybinds.qml", 'execDetached(["sh", "-c", item.cmd]',
     "runs the user's own keybind command -- that is the feature"),
    ("modules/launcher/services/Keybinds.qml", 'execDetached(["sh", "-c", action.slice(5)]',
     "same: a user-configured action string"),
    ("modules/launcher/services/Animations.qml", 'execDetached(["sh", "-c", script]',
     "runs a user-provided animation script"),
    ("modules/lock/Resources.qml", 'command.join(" ")',
     "a session command assembled from the user's own config"),
    ("modules/session/Content.qml", 'command.join(" ")',
     "same"),
    ("modules/nexus/pages/hyprland/HyprVariablesPage.qml", "cat << 'EOF' >",
     "writes the user's own Hyprland config through a quoted heredoc"),
    ("modules/nexus/pages/hyprland/HyprKeybindsPage.qml", "cat << 'EOF' >",
     "same"),
    ("modules/launcher/items/CalcItem.qml", "exec qalc -i",
     "the launcher's own calculator input; no boundary crossed, and fixing it needs fish "
     "escaping in a path that spawns a terminal (T26)"),
]


def allowed(rel, line):
    for f, snippet, why in ALLOWED:
        if rel == f and snippet in line:
            return why
    return None


def tracked_files(*patterns):
    """git ls-files, but a failure or an empty result is an error rather than a pass.

    In a container the checkout is often owned by another uid, git refuses with "detected
    dubious ownership", ls-files prints nothing and exits non-zero -- and a checker that
    simply iterates the result then reports "0 files, 0 problems" and succeeds. All three
    git-based checkers did exactly that on their first CI run. Zero inputs is a broken
    checker, never a clean tree.
    """
    r = subprocess.run(["git", "-C", str(ROOT), "ls-files",
                        "--cached", "--others", "--exclude-standard", *patterns],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"git ls-files failed ({r.returncode}): {r.stderr.strip()}\n"
                 f"in a container, run: git config --global --add safe.directory {ROOT}")
    files = r.stdout.split()
    if not files:
        sys.exit(f"git ls-files {patterns} matched nothing under {ROOT} -- refusing to "
                 f"report a clean result from an empty file list")
    return files


def main():
    files = tracked_files("*.qml")

    # the script argument of an sh -c / bash -c invocation, on one line
    call = re.compile(r'\[\s*(?:\.\.\.[\w.]+\s*,\s*)?"(?:ba)?sh"\s*,\s*"-c"\s*,\s*(.*)')

    def script_expr(rest):
        """The third array element as a whole expression, stopping at the comma that ends
        it. Both halves matter: a value can be interpolated *inside* the literal with ${},
        or concatenated *outside* it with +, and reading only the literal misses the second
        while reading the whole line misses nothing and flags correct calls."""
        depth, quote, out, i = 0, None, [], 0
        while i < len(rest):
            c = rest[i]
            if quote:
                if c == "\\":
                    out.append(rest[i:i + 2]); i += 2; continue
                if c == quote:
                    quote = None
            elif c in "\"'`":
                quote = c
            elif c in "([{":
                depth += 1
            elif c in ")]}":
                if depth == 0:
                    break           # the array's own closing bracket
                depth -= 1
            elif c == "," and depth == 0:
                break               # end of the script argument
            out.append(c)
            i += 1
        return "".join(out)

    findings, skipped, total = [], [], 0
    for rel in files:
        for n, line in enumerate(Path(ROOT / rel).read_text().split("\n"), 1):
            m = call.search(line)
            if not m:
                continue
            total += 1
            script = script_expr(m.group(1))
            interpolated = "${" in script or "+" in script
            why = allowed(rel, line)
            if why:
                skipped.append((rel, n, why))
            elif interpolated:
                findings.append((rel, n, line.strip()))

    for rel, n, why in skipped:
        if VERBOSE:
            print(f"  allowed {rel}:{n}  -- {why}")

    for rel, n, text in findings:
        print(f"  UNSAFE  {rel}:{n}")
        print(f"          {text[:120]}")

    print(f"\n{total} shell invocation(s), {len(skipped)} allowlisted, "
          f"{len(findings)} building the script from a value")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
