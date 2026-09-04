#!/usr/bin/env bash
# Run Qt's qmllint the way .github/workflows/lint.yml does.
#
#   ./hybrid/tools/qml-lint.sh                    # lint everything; any output = failure
#   ./hybrid/tools/qml-lint.sh --summary          # category counts instead of raw output
#   ./hybrid/tools/qml-lint.sh --fix --dry-run    # preview automatic fixes
#   ./hybrid/tools/qml-lint.sh --fix              # apply them (commit first)
#   ./hybrid/tools/qml-lint.sh services/Audio.qml # a subset
#   ./hybrid/tools/qml-lint.sh --self-test        # prove the gate can still fail
#
# Anything not recognised here is passed straight through to qmllint.
#
# Two things this exists to get right (trap T13):
#
#   * /usr/bin/qmllint on Arch/CachyOS is an UNRELATED tool reporting "qmllint 1.0"
#     that rejects --import. Qt's lives in /usr/lib/qt6/bin. A run that "passes" with
#     one line of output is that decoy, not a clean tree.
#   * The -I import paths come from .qmlls.ini, which is produced as a side effect of
#     booting the shell offscreen. That boot fails on PanelWindow (T12) and is SUPPOSED
#     to -- its exit code is meaningless. It also writes to XDG state/cache, so it runs
#     with those isolated.

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

BUILD_DIR=${BUILD_DIR:-$ROOT/build}
QS=${QS:-qs}
QMLLINT=${QMLLINT:-/usr/lib/qt6/bin/qmllint}

SUMMARY=0
PASSTHRU=()
FILES=()

SELFTEST=0

while [ $# -gt 0 ]; do
    case $1 in
        --summary)   SUMMARY=1; shift ;;
        --self-test) SELFTEST=1; shift ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        -*)        PASSTHRU+=("$1"); shift ;;
        *)         FILES+=("$1"); shift ;;
    esac
done

red()   { printf '\033[1;31m%s\033[0m' "$*"; }
green() { printf '\033[1;32m%s\033[0m' "$*"; }
yellow(){ printf '\033[1;33m%s\033[0m' "$*"; }

[ -x "$QMLLINT" ] || { printf '%s %s not found. Install qt6-declarative.\n' "$(red fail)" "$QMLLINT"; exit 2; }
case "$("$QMLLINT" --version 2>&1)" in
    *" 6."*) : ;;
    *) printf '%s %s reports "%s" - that is not Qt'"'"'s qmllint (trap T13).\n' \
           "$(red fail)" "$QMLLINT" "$("$QMLLINT" --version 2>&1)"; exit 2 ;;
esac
[ -d "$BUILD_DIR/qml" ] || {
    printf '%s %s/qml missing - build first:  cmake -B build -G Ninja && cmake --build build\n' "$(red fail)" "$BUILD_DIR"
    exit 2
}

# ------------------------------------------------- import paths via .qmlls.ini

# Two things about .qmlls.ini, both load-bearing:
#
#   * qs only WRITES it if the path already exists -- hence upstream's `touch`.
#     Without that, the run silently produces nothing.
#   * What it then leaves behind is a SYMLINK into that run's VFS
#     (/run/user/.../quickshell/vfs/<shell-id>/). That dir is transient, so the link
#     goes dangling later, and writing through a dangling symlink fails with ENOENT.
#
# So: clear, then create, then run. `-s` follows the link, so a dangling one is falsy
# and regenerates.
#
# It must ALSO regenerate when the tree has changed, and originally did not. The VFS that
# .qmlls.ini points into is a *snapshot* of the QML tree at the moment it was written, so a
# stale one that still resolves is worse than a missing one: a newly added file is reported
# as an unresolved type, and a deleted one still resolves, which hides a real error. Adding
# services/Hotspot.qml produced eight "Unqualified access" warnings against a snapshot taken
# hours earlier, on a file that was perfectly correct.
#
# Cheapest sufficient test: is any .qml newer than the link itself.
#
# This must include UNTRACKED files. `git ls-files` lists only tracked ones, and a freshly
# imported or newly written .qml is untracked at exactly the moment it needs to be picked
# up -- so keying on tracked files alone would miss the one case this check exists for and
# would appear to work only because some other file happened to be newer. `--others
# --exclude-standard` adds untracked-but-not-ignored files; `--cached` keeps tracked ones.
#
# mtime alone cannot see a DELETION -- removing a .qml leaves every survivor older than the
# link, so the snapshot would keep resolving a type that no longer exists. Compare the set
# of paths as well: that is exact for both additions and deletions, and the mtime test then
# only has to catch edits to files that were already there.
stale=0
if [ -s .qmlls.ini ]; then
    vfs=$(grep -oP 'buildDir="\K[^"]+' .qmlls.ini 2>/dev/null || true)
    newest=$(git ls-files -z --cached --others --exclude-standard '*.qml' 2>/dev/null |
        xargs -0 -r ls -t 2>/dev/null | head -1)
    if [ -z "$vfs" ] || [ ! -d "$vfs/qs" ]; then
        stale=1
    elif [ -n "$newest" ] && [ "$newest" -nt .qmlls.ini ]; then
        stale=1
    elif ! diff -q \
        <(git ls-files --cached --others --exclude-standard '*.qml' | sort) \
        <(cd "$vfs/qs" && find . -name '*.qml' | sed 's|^\./||' | sort) >/dev/null 2>&1; then
        stale=1
    fi
fi

if [ ! -s .qmlls.ini ] || [ "$stale" = 1 ]; then
    tmp=$(mktemp -d)
    rm -f .qmlls.ini
    touch .qmlls.ini
    XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" XDG_CONFIG_HOME="$tmp/config" \
    QT_QPA_PLATFORM=offscreen QS_NO_RELOAD_POPUP=1 \
    QML2_IMPORT_PATH="$BUILD_DIR/qml:${QML2_IMPORT_PATH:-}" \
        timeout 10 "$QS" -p "$ROOT" >/dev/null 2>&1   # exit code is meaningless here
    rm -rf "$tmp"
fi
[ -s .qmlls.ini ] || { printf '%s could not generate .qmlls.ini\n' "$(red fail)"; exit 2; }

ARGS=()
bd=$(grep -oP '(?<=buildDir=")(.*)(?=")' .qmlls.ini || true)
[ -n "$bd" ] && ARGS+=(-I "$bd")
imp=$(grep -oP '(?<=importPaths=")(.*)(?=")' .qmlls.ini || true)
if [ -n "$imp" ]; then
    IFS=':' read -ra paths <<< "$imp"
    for p in "${paths[@]}"; do [ -n "$p" ] && ARGS+=(-I "$p"); done
fi

# ---------------------------------------------------------------------- files

if [ ${#FILES[@]} -eq 0 ]; then
    mapfile -t FILES < <(find . -name '*.qml' -not -path './build/*' -not -path './.git/*' | sort)
fi
[ ${#FILES[@]} -gt 0 ] || { printf '%s no qml files\n' "$(red fail)"; exit 2; }

# ------------------------------------------------------------ self-test (T23, T48)
#
# A gate nobody has watched fail is not known to work, and a gate nobody has watched pass on
# known-bad input is not known to be strict enough. This script had the second problem: it
# deferred to qmllint's exit code, which is 0 when every diagnostic printed is Info-level, so
# it printed `Unused import` and exited 0 while CI failed on the identical tree. The probe
# below is deliberately an *Info*-level finding for that reason -- a Warning-level one would
# have passed even before the bug was fixed, and proved nothing.
if [ "$SELFTEST" = 1 ]; then
    probe=$ROOT/components/__lint_self_test.qml
    trap 'rm -f "$probe"' EXIT
    # `import QtQml` is unused by an Item, which qmllint reports at Info level.
    printf 'import QtQuick\nimport QtQml\n\nItem {\n}\n' > "$probe"

    printf '%s self-test: expecting this run to FAIL\n\n' "$(yellow note)"
    if "$0" "$probe" >/dev/null 2>&1; then
        printf '%s self-test: the gate PASSED a file with a known Info-level finding.\n' "$(red FAIL)"
        printf '       It is not enforcing what lint.yml enforces (`test -z "$lint_out"`).\n'
        exit 1
    fi
    printf '%s self-test: the gate rejected an Info-level finding, as CI does\n' "$(green PASS)"
    exit 0
fi

# ------------------------------------------------------------------------ run

out=$(mktemp)
# --bare drops qmllint's *default* import directory. Without it that directory takes
# priority over every -I we pass, so an installed caelestia/midnight-shell package
# shadows ./build/qml and the tree is linted against whatever is in /usr/lib/qt6/qml
# instead of what was just built. See trap T18.
"$QMLLINT" --bare --import disable "${PASSTHRU[@]}" "${ARGS[@]}" "${FILES[@]}" > "$out" 2>&1
rc=$?

if [ "$SUMMARY" = 1 ]; then
    # Count diagnostics, not output lines: each one ends in a [category] tag, and is
    # followed by source context and Info: explanation lines that must not be counted.
    total=$(grep -cP '\[[A-Za-z0-9.-]+\]$' "$out" || true)
    printf 'linted %d file(s) with %s\n\n' "${#FILES[@]}" "$("$QMLLINT" --version)"
    if [ "$total" -eq 0 ]; then
        printf '%s no warnings\n' "$(green clean)"
    else
        printf 'by category:\n'
        grep -oP '\[\K[A-Za-z0-9.-]+(?=\]$)' "$out" | sort | uniq -c | sort -rn \
            | while read -r n c; do printf '  %6s  %s\n' "$n" "$c"; done
        printf '\nby file (top 15):\n'
        grep -oP '^(Warning|Error|Info): \K\S+\.qml(?=:[0-9])' "$out" | sort | uniq -c | sort -rn | head -15 \
            | while read -r n f; do printf '  %6s  %s\n' "$n" "$f"; done
        printf '\n%s %s diagnostic(s)\n' "$(red total)" "$total"
    fi
    rm -f "$out"
    [ "$total" -eq 0 ] && exit 0 || exit 1
fi

cat "$out"
size=$(wc -c < "$out")
rm -f "$out"
[ "$size" -eq 0 ] && exit 0

# Any output is a failure. That is CI's rule verbatim -- lint.yml ends with
# `test -z "$lint_out" || exit 1` -- and deferring to qmllint's own exit code is NOT the same
# thing, because qmllint returns 0 when every diagnostic it printed is Info-level. So this
# script printed `Info: ... Unused import [unused-imports]` and exited 0, the gate reported
# clean, and the same tree failed lint-qml in CI. Twice. See trap T48.
exit 1
