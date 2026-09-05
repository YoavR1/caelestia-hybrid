#!/usr/bin/env bash
# Every config path the settings UI touches must exist in the real schema.
#
# The settings pages reach keys by path -- `targetConfig.bar.position`. A path with a
# typo, or one left behind when a key was renamed, writes nowhere and reports nothing:
# QML resolves it to undefined, the control renders, and the setting silently does
# nothing. That is the same shape as T62, where the *scope* was wrong rather than the
# path, and it is invisible to every other gate here.
#
# The schema is compiled C++, so the only honest source for what exists is the running
# plugin. This boots it offscreen under an isolated XDG_CONFIG_HOME, dumps every
# reachable property path, and checks the settings tree against that.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QS=${QS:-qs}
BUILD_DIR=${BUILD_DIR:-$ROOT/build}

command -v "$QS" >/dev/null || { echo "qs not found on PATH" >&2; exit 2; }
[ -d "$BUILD_DIR/qml" ] || { echo "$BUILD_DIR/qml missing -- build first" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
dump=$tmp/paths.txt

QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
CONFIG_PATHS_OUT="$dump" \
QML2_IMPORT_PATH="$BUILD_DIR/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}" \
CAELESTIA_LIB_DIR="$BUILD_DIR/lib" \
    timeout 90 "$QS" -p "$ROOT/hybrid/tools/tests/config-paths" >"$tmp/run.log" 2>&1

if [ ! -s "$dump" ]; then
    echo "  settings-paths: the schema dump is empty -- refusing to report a clean result"
    grep -aE 'ERROR|error:|Failed' "$tmp/run.log" | head -5 | sed 's/^/      /'
    exit 1
fi

python3 - "$dump" <<'PY'
import re, subprocess, sys, pathlib

paths = set(open(sys.argv[1]).read().split())
if len(paths) < 100:
    sys.exit(f"  only {len(paths)} schema path(s); the dump looks wrong, refusing to pass")

files = subprocess.check_output(["git", "ls-files", "modules/nexus/*.qml"], text=True).split()

REF = re.compile(r'\b(?:root\.)?(?:targetConfig|GlobalConfig|Config)\.((?:[A-Za-z_]\w*)(?:\.[A-Za-z_]\w*)*)')

# Members of the resolver or the attached object, not config keys.
NOT_KEYS = {"forScreen", "screen", "instance", "asJson", "reset", "save", "load"}

# Methods called *on* a config value. A list key is a ListNode and a string key is a
# JS string, so `.includes`, `.join` and `.toLowerCase` are ordinary calls rather
# than paths. Without this the checker reports twelve findings that are all correct code.
CALLS = {
    "join", "includes", "find", "filter", "map", "forEach", "indexOf", "lastIndexOf",
    "slice", "splice", "split", "concat", "some", "every", "reduce", "sort", "reverse",
    "push", "pop", "shift", "unshift", "at", "insert", "remove", "move", "clear",
    "length", "toLowerCase", "toUpperCase", "trim", "replace", "startsWith", "endsWith",
    "charAt", "substring", "toString", "valueOf", "hasOwnProperty", "keys", "values",
}

bad, total = {}, 0
for f in files:
    for n, line in enumerate(pathlib.Path(f).read_text().splitlines(), 1):
        st = line.lstrip()
        if st.startswith("//") or st.startswith("*"):
            continue
        for m in REF.finditer(line):
            parts = m.group(1).split(".")
            if parts[0] in NOT_KEYS:
                continue
            while parts and parts[-1] in CALLS:
                parts.pop()
            if not parts:
                continue
            path = ".".join(parts)
            total += 1
            if path not in paths:
                for i in range(len(parts) - 1, 0, -1):
                    if ".".join(parts[:i]) in paths:
                        break
                else:
                    i = 0
                bad[(f, n, path)] = ".".join(parts[:i + 1])

for (f, n, path), first_bad in sorted(bad.items()):
    print(f"  \033[0;31m[missing]\033[0m {f}:{n}: {path}  (unknown at {first_bad})")
if bad:
    print()
print(f"{len(paths)} schema path(s), {total} reference(s) in the settings UI, "
      f"{len(bad)} pointing at nothing")
sys.exit(1 if bad else 0)
PY
