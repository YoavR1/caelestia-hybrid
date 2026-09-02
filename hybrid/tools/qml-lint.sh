#!/usr/bin/env bash
# Run Qt's qmllint the way .github/workflows/lint.yml does.
#
#   ./hybrid/tools/qml-lint.sh                    # lint everything; any output = failure
#   ./hybrid/tools/qml-lint.sh --summary          # category counts instead of raw output
#   ./hybrid/tools/qml-lint.sh --fix --dry-run    # preview automatic fixes
#   ./hybrid/tools/qml-lint.sh --fix              # apply them (commit first)
#   ./hybrid/tools/qml-lint.sh services/Audio.qml # a subset
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

while [ $# -gt 0 ]; do
    case $1 in
        --summary) SUMMARY=1; shift ;;
        -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
        -*)        PASSTHRU+=("$1"); shift ;;
        *)         FILES+=("$1"); shift ;;
    esac
done

red()   { printf '\033[1;31m%s\033[0m' "$*"; }
green() { printf '\033[1;32m%s\033[0m' "$*"; }

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
if [ ! -s .qmlls.ini ]; then
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
exit "${rc:-1}"
