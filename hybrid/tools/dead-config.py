#!/usr/bin/env python3
"""Find config keys the schema declares that nothing ever reads.

    ./hybrid/tools/dead-config.py            # report; exit 1 if any are found
    ./hybrid/tools/dead-config.py --verbose  # also list the allowlisted keys

A dead config key is invisible in a way the other gates cannot help with. `settings::Node`
warns on an *unknown* key, so a typo is caught loudly -- but a key that is genuinely in the
compiled schema and simply has no reader is accepted in silence. You set it in `shell.json`,
the shell says nothing, and nothing changes. Fifteen of these were found by hand (trap T28);
this is that sweep, made repeatable, so there is never a sixteenth nobody noticed.

T28 documented the algorithm and, more usefully, the three ways a naive version gets it
wrong. Each of these produced a false positive on the first attempt:

  * **C++ consumers.** A QML-only sweep called `logout`, `shutdown`, `italic`, `vaxes`,
    `lyricsBackend` and `configLoaded` dead. All six are read from C++.
  * **The declaration itself.** Searching C++ for the bare name matches the `CONFIG_PROPERTY`
    line that declares it, so every key looks live unless those lines are excluded first.
  * **Dynamic access.** `modules/background/Wallpaper.qml` reads
    `Config.background["wallpaperRecolor"]`. A string-literal subscript is caught by the
    `"name"` check; a computed one would not be, and there are none today.

Scope: value keys only -- `CONFIG_PROPERTY`, `CONFIG_GLOBAL_PROPERTY`, the `ENUM` variants,
the `LIST` ones, and the `FEATURE`/`VARIANT` wrappers. Subobject nodes are containers reached
through their children, so a live child keeps the parent live and checking them separately
only adds noise.

**Known limitation, stated so nobody reads more into a clean run than it means.** Keys are
matched by bare name, not by owning class, because deciding which class a `Config.foo.enabled`
reaches needs real C++ type resolution. So a dead `enabled` in one class is hidden by a live
`enabled` in another. That is a false *negative* -- this tool can miss a dead key, but it does
not invent one -- and it is the same limitation the manual sweep in T28 had. Every key it does
report is genuinely unread.
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERBOSE = "--verbose" in sys.argv

# The name is the second macro argument. No declared type contains a comma today (checked),
# so a comma split is safe; if one ever does, this regex is where it breaks.
#
# FEATURE() and VARIANT() are counted too. They are one-argument wrappers around
# CONFIG_GLOBAL_PROPERTY defined in hybridconfig.hpp, so a regex looking only for the
# CONFIG_ macros sees none of the 18 flag keys -- and a feature flag nothing reads is
# precisely the kind of dead key worth catching. The header says "a flag exists here only
# once something reads it"; this is what makes that true rather than aspirational.
DECL_RE = re.compile(
    r"\bCONFIG_(?:GLOBAL_)?(?:ENUM_)?(?:PROPERTY|LIST)\s*\(\s*[^,()]+,\s*([A-Za-z_]\w*)"
    r"|\b(?:FEATURE|VARIANT|THEMED_PATH)\s*\(\s*([A-Za-z_]\w*)"
)

# Wrapper macros whose first argument is the key name. FEATURE/VARIANT wrap
# CONFIG_GLOBAL_PROPERTY, THEMED_PATH wraps CONFIG_PROPERTY. They are listed above, and
# `check_wrappers_known` below fails the run if a new one appears -- because a wrapper this
# tool has not been told about does not produce a false positive, it produces a **silent
# hole**: every key declared through it drops out of the schema count and can never be
# reported dead. That happened twice. FEATURE/VARIANT hid all 18 flags until the count was
# questioned, and THEMED_PATH hid four path keys the same way a release later.
KNOWN_WRAPPERS = {"FEATURE", "VARIANT", "THEMED_PATH"}
WRAPPER_DEF_RE = re.compile(r"^\s*#define\s+([A-Z][A-Z0-9_]*)\s*\(([^)]*)\)")


def declared_names(line: str):
    """Key names declared on this line, ignoring the #define that creates the macro itself.

    Without the #define guard, `#define CONFIG_ENUM_PROPERTY(Type, name, defaultVal)` in
    common.hpp registers a key literally called `name`, which then looks live because `.name`
    appears all over the QML. A checker with a phantom key in its list is one bad grep away
    from a phantom clean result.
    """
    if line.lstrip().startswith("#define"):
        return []
    return [a or b for a, b in DECL_RE.findall(line)]

ALLOWED = {
    # --- superseded, and provably so (T28) ------------------------------------------------
    "videoWallpaperPauseOnFullscreen": "BackgroundConfig",
    "videoWallpaperPauseOnTiled": "BackgroundConfig",
    "videoWallpaperPauseOnAllDisplays": "BackgroundConfig",
    "videoWallpaperSoundEnabled": "BackgroundConfig",
    "videoWallpaperMuteOnMedia": "BackgroundConfig",
    # --- may be half-wired rather than debris; guessing deletes someone's groundwork -------
    "activeOllamaModel": "AiConfig",
    "activeProvider": "AiConfig",
    "defaultProvider": "AiConfig",
    "ollamaModel": "AiConfig",
    "orionModel": "AiConfig",
    "saveChatHistory": "AiConfig",
    "snapToDefaultOllama": "AiConfig",
    # --- unknown provenance ---------------------------------------------------------------
    "screenCounts": "ShimejiConfig",
    "tabIndicatorHeight": "DashboardTokens",
    "wsIcons": "BarWorkspaces",
}

ALLOW_REASON = (
    "known dead, deliberately kept -- see trap T28. Removing a key is user-visible: an "
    "existing shell.json containing it starts emitting `Unknown option`, which the smoke "
    "matrix treats as a failure. Right for a key that is genuinely gone, wrong for one "
    "someone is halfway through wiring."
)


def check_wrappers_known(headers):
    """Fail if a header defines a macro that expands to a config property we do not parse."""
    unknown = []
    for f in headers:
        text = (ROOT / f).read_text()
        for i, line in enumerate(text.splitlines()):
            m = WRAPPER_DEF_RE.match(line)
            # CONFIG_* names are matched by DECL_RE directly, so a macro that merely renames
            # one of them (CONFIG_LIST -> SETTINGS_LIST) is already covered and is not a hole.
            if not m or m.group(1) in KNOWN_WRAPPERS or m.group(1).startswith("CONFIG_"):
                continue
            # A macro definition can continue over backslash-continued lines; look at the
            # whole run before deciding it does not declare a property.
            body, n = line, i
            lines = text.splitlines()
            while body.rstrip().endswith("\\") and n + 1 < len(lines):
                n += 1
                body += lines[n]
            # A wrapper is only a hole if the property NAME comes from one of its
            # parameters. FONT_CONFIG/FONT_STYLE generate whole classes but name their keys
            # literally -- `CONFIG_PROPERTY(QString, family, ...)` -- so DECL_RE already sees
            # `family` in the macro body and nothing is hidden. THEMED_PATH(name, ...) and
            # FEATURE(name) pass the name *through*, which is what makes them invisible.
            params = {a.strip() for a in m.group(2).split(",") if a.strip()}
            declared = re.findall(
                r"CONFIG_(?:GLOBAL_)?(?:ENUM_)?(?:PROPERTY|LIST)\s*\(\s*[^,()]+,\s*([A-Za-z_]\w*)", body)
            if params & set(declared):
                unknown.append(f"{f}:{i + 1}: {m.group(1)}")
    if unknown:
        print("  wrapper macro(s) this checker does not parse -- every key declared through")
        print("  them is invisible here. Add the name to KNOWN_WRAPPERS and to DECL_RE:")
        for u in unknown:
            print(f"    {u}")
    return unknown


def tracked(*patterns):
    out = subprocess.run(["git", "-C", str(ROOT), "ls-files", *patterns],
                         capture_output=True, text=True, check=True).stdout.split()
    if not out:
        sys.exit(f"git ls-files {patterns} matched nothing under {ROOT} -- refusing to "
                 f"report a clean result from an empty file list")
    return out


def main():
    headers = [f for f in tracked("plugin/src/Caelestia/Config/*.hpp")]

    if check_wrappers_known(headers):
        return 1

    keys = {}
    for f in headers:
        for n, line in enumerate((ROOT / f).read_text().splitlines(), 1):
            for name in declared_names(line):
                keys.setdefault(name, (f, n))

    # C++ text with every declaration line removed, so a key is never kept alive by the
    # macro that declares it.
    cpp = []
    for f in tracked("*.cpp", "*.hpp"):
        for line in (ROOT / f).read_text(errors="ignore").splitlines():
            if not declared_names(line):
                cpp.append(line)
    cpp_text = "\n".join(cpp)

    qml_text = "\n".join((ROOT / f).read_text(errors="ignore") for f in tracked("*.qml"))

    dead, skipped = [], []
    for key, (f, n) in sorted(keys.items()):
        if re.search(rf"\.{key}\b", qml_text) or f'"{key}"' in qml_text:
            continue
        if re.search(rf"(?<![\w.]){key}\b", cpp_text):
            continue
        (skipped if key in ALLOWED else dead).append((key, f, n))

    if VERBOSE and skipped:
        print(f"  allowlisted ({ALLOW_REASON})")
        for key, f, n in skipped:
            print(f"    {key:38} {ALLOWED[key]:18} {f}:{n}")

    for key, f, n in dead:
        print(f"  DEAD  {key:38} {f}:{n}")

    print(f"\n{len(keys)} config key(s), {len(skipped)} allowlisted, {len(dead)} with no reader")
    return 1 if dead else 0


if __name__ == "__main__":
    sys.exit(main())
