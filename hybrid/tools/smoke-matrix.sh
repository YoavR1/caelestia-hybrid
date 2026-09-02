#!/usr/bin/env bash
# Boot the shell headless under each preset and fail on QML errors.
#
# This is the project's verification gate (architecture.md §5). It is how arbitrary
# feature/variant combinations get covered without a combinatorial test explosion:
# each run costs seconds, so dozens of combinations per CI run are affordable.
#
#   ./hybrid/tools/smoke-matrix.sh                    # every preset
#   ./hybrid/tools/smoke-matrix.sh recommended op     # named presets only
#   ./hybrid/tools/smoke-matrix.sh --timeout 25
#   ./hybrid/tools/smoke-matrix.sh --keep-logs
#   ./hybrid/tools/smoke-matrix.sh --baseline         # record environment noise (see below)
#
# Env:
#   BUILD_DIR   default ./build
#   QS          quickshell binary, default `qs`
#
# FIRST RUN: a headless container has no Hyprland socket, no PipeWire and no session bus,
# so the shell will emit diagnostics that are environmental rather than real. Run once with
# --baseline to append those to hybrid/tools/smoke-ignore.txt, then READ that file and delete
# any line that is a genuine bug. Do not baseline blindly; the ignore file is reviewed code.

set -uo pipefail

cd "$(git rev-parse --show-toplevel 2>/dev/null || dirname "$0")/.." 2>/dev/null || true
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"

BUILD_DIR=${BUILD_DIR:-$ROOT/build}
QS=${QS:-qs}
PRESET_DIR=$ROOT/hybrid/presets
IGNORE_FILE=$ROOT/hybrid/tools/smoke-ignore.txt
LOG_DIR=$ROOT/.smoke-logs

TIMEOUT_S=15
KEEP_LOGS=0
BASELINE=0
WANTED=()

while [ $# -gt 0 ]; do
    case $1 in
        --timeout)   TIMEOUT_S=$2; shift 2 ;;
        --keep-logs) KEEP_LOGS=1; shift ;;
        --baseline)  BASELINE=1; KEEP_LOGS=1; shift ;;
        -h|--help)   sed -n '2,26p' "$0"; exit 0 ;;
        -*)          printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
        *)           WANTED+=("$1"); shift ;;
    esac
done

red()   { printf '\033[1;31m%s\033[0m' "$*"; }
green() { printf '\033[1;32m%s\033[0m' "$*"; }
yellow(){ printf '\033[1;33m%s\033[0m' "$*"; }

# ------------------------------------------------------------------ preflight

[ "$(uname -s)" = "Linux" ] || { printf '%s this only runs on Linux (Quickshell + Qt6 + Wayland)\n' "$(red fail)"; exit 2; }
command -v "$QS" >/dev/null || { printf '%s %s not found on PATH\n' "$(red fail)" "$QS"; exit 2; }
command -v timeout >/dev/null || { printf '%s coreutils timeout not found\n' "$(red fail)"; exit 2; }
[ -d "$BUILD_DIR/qml" ] || {
    printf '%s %s/qml missing — build first:\n' "$(red fail)" "$BUILD_DIR"
    printf '      cmake -B build -G Ninja && cmake --build build\n'
    exit 2
}

mkdir -p "$LOG_DIR"

# Diagnostics that are always a failure, regardless of the ignore file.
HARD='ReferenceError|TypeError|SyntaxError|is not defined|Unable to assign|Cannot assign|Cannot read propert|QQmlApplicationEngine failed|Binding loop detected|must be a type|Invalid property|Cannot create|no such file or directory.*\.qml'

# Any QML diagnostic line at all. Suppressible via the ignore file.
SOFT='\.qml:[0-9]+'

filter_ignored() {
    if [ -s "$IGNORE_FILE" ] && grep -qEv '^[[:space:]]*(#|$)' "$IGNORE_FILE" 2>/dev/null; then
        grep -Ev -f <(grep -Ev '^[[:space:]]*(#|$)' "$IGNORE_FILE") || true
    else
        cat
    fi
}

# ------------------------------------------------------------------- presets

presets=()
if [ ${#WANTED[@]} -gt 0 ]; then
    for w in "${WANTED[@]}"; do
        if   [ -f "$w" ];                       then presets+=("$w")
        elif [ -f "$PRESET_DIR/$w.json" ];      then presets+=("$PRESET_DIR/$w.json")
        else printf '%s no such preset: %s\n' "$(red fail)" "$w" >&2; exit 2
        fi
    done
else
    while IFS= read -r p; do presets+=("$p"); done < <(find "$PRESET_DIR" -maxdepth 1 -name '*.json' | sort)
fi

[ ${#presets[@]} -gt 0 ] || { printf '%s no presets found in %s\n' "$(red fail)" "$PRESET_DIR"; exit 2; }

printf 'smoke matrix: %d preset(s), %ss window each\n\n' "${#presets[@]}" "$TIMEOUT_S"

# ---------------------------------------------------------------------- run

failures=0
for preset in "${presets[@]}"; do
    name=$(basename "$preset" .json)
    log=$LOG_DIR/$name.log
    cfg=$(mktemp -d)

    mkdir -p "$cfg/caelestia"
    cp "$preset" "$cfg/caelestia/shell.json"

    printf '  %-16s ' "$name"

    XDG_CONFIG_HOME="$cfg" \
    XDG_CACHE_HOME="$cfg/cache" \
    XDG_STATE_HOME="$cfg/state" \
    QT_QPA_PLATFORM=offscreen \
    QS_NO_RELOAD_POPUP=1 \
    QML2_IMPORT_PATH="$BUILD_DIR/qml:${QML2_IMPORT_PATH:-}" \
        timeout -s TERM "$TIMEOUT_S" "$QS" -p "$ROOT" >"$log" 2>&1
    rc=$?

    # rc 124 == still alive when we killed it == it booted and stayed up. That is success.
    if [ $rc -ne 124 ]; then
        printf '%s  (exited early, rc=%d)\n' "$(red FAIL)" "$rc"
        sed -n '1,25p' "$log" | sed 's/^/        /'
        failures=$((failures + 1))
        rm -rf "$cfg"
        continue
    fi

    hard_hits=$(grep -En "$HARD" "$log" | filter_ignored || true)
    soft_hits=$(grep -En "$SOFT" "$log" | grep -Ev "$HARD" | filter_ignored || true)

    if [ -n "$hard_hits" ] || [ -n "$soft_hits" ]; then
        printf '%s\n' "$(red FAIL)"
        [ -n "$hard_hits" ] && printf '%s\n' "$hard_hits" | head -20 | sed 's/^/        /'
        [ -n "$soft_hits" ] && printf '%s\n' "$soft_hits" | head -20 | sed 's/^/        /'
        failures=$((failures + 1))

        if [ "$BASELINE" = 1 ]; then
            {
                printf '\n# --- baselined from preset %s on %s ---\n' "$name" "$(date -Is)"
                printf '%s\n%s\n' "$hard_hits" "$soft_hits" \
                    | sed 's/^[0-9]*://' \
                    | sed -E 's/[0-9]+/[0-9]+/g' \
                    | sed -E 's/[][(){}.*+?^$|\\]/\\&/g; s/\\\[0-9\\\]\\\+/[0-9]+/g' \
                    | sort -u | grep -v '^$'
            } >> "$IGNORE_FILE"
        fi
    else
        printf '%s\n' "$(green ok)"
    fi

    rm -rf "$cfg"
    [ "$KEEP_LOGS" = 1 ] || rm -f "$log"
done

echo
if [ "$BASELINE" = 1 ]; then
    printf '%s baseline written to %s\n' "$(yellow note)" "$IGNORE_FILE"
    printf '     READ IT. Delete every line that is a real bug rather than environment noise.\n'
    exit 0
fi

if [ "$failures" -gt 0 ]; then
    printf '%s %d/%d preset(s) failed' "$(red FAIL)" "$failures" "${#presets[@]}"
    [ "$KEEP_LOGS" = 1 ] && printf ' — logs in %s' "$LOG_DIR"
    printf '\n'
    exit 1
fi

printf '%s all %d preset(s) booted clean\n' "$(green PASS)" "${#presets[@]}"
