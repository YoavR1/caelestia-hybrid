#!/usr/bin/env bash
# Boot the shell under each preset in a throwaway compositor and fail on QML errors.
#
# This is the project's verification gate (architecture.md §5). It is how arbitrary
# feature/variant combinations get covered without a combinatorial test explosion:
# each preset costs seconds, so dozens per CI run are affordable.
#
#   ./hybrid/tools/smoke-matrix.sh                    # every preset
#   ./hybrid/tools/smoke-matrix.sh recommended op     # named presets only
#   ./hybrid/tools/smoke-matrix.sh --timeout 25
#   ./hybrid/tools/smoke-matrix.sh --keep-logs
#   ./hybrid/tools/smoke-matrix.sh --baseline         # record environment noise
#
# Env:
#   BUILD_DIR    default ./build
#   QS           quickshell binary, default `qs`
#   SMOKE_SOCKET pre-existing WAYLAND_DISPLAY to test against instead of spawning
#                a nested compositor. Must NOT be your live session (see below).
#
# WHY A COMPOSITOR: Quickshell's PanelWindow is a wlr-layer-shell surface. Without a
# Wayland backend it is unavailable, and the failure poisons the whole singleton graph
# ("No PanelWindow backend loaded"). QT_QPA_PLATFORM=offscreen therefore CANNOT boot
# this shell. Upstream's lint.yml runs an offscreen `qs` only to emit .qmlls.ini for the
# linter -- its exit code is never checked. So we spawn a nested Hyprland instead.
#
# FIRST RUN: some warnings are environmental (no bluetooth, a notification daemon already
# owns the bus name, no polkit slot). Run once with --baseline to append those to
# hybrid/tools/smoke-ignore.txt, then READ that file and delete anything that is a genuine
# bug. It is reviewed code, not a dumping ground.

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

BUILD_DIR=${BUILD_DIR:-$ROOT/build}
QS=${QS:-qs}
PRESET_DIR=$ROOT/hybrid/presets
IGNORE_FILE=$ROOT/hybrid/tools/smoke-ignore.txt
LOG_DIR=$ROOT/.smoke-logs
RUNTIME=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

TIMEOUT_S=15
KEEP_LOGS=0
BASELINE=0
WANTED=()

while [ $# -gt 0 ]; do
    case $1 in
        --timeout)   TIMEOUT_S=$2; shift 2 ;;
        --keep-logs) KEEP_LOGS=1; shift ;;
        --baseline)  BASELINE=1; KEEP_LOGS=1; shift ;;
        -h|--help)   sed -n '2,34p' "$0"; exit 0 ;;
        -*)          printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
        *)           WANTED+=("$1"); shift ;;
    esac
done

red()   { printf '\033[1;31m%s\033[0m' "$*"; }
green() { printf '\033[1;32m%s\033[0m' "$*"; }
yellow(){ printf '\033[1;33m%s\033[0m' "$*"; }
strip() { sed 's/\x1b\[[0-9;]*m//g'; }

# ------------------------------------------------------------------ preflight

[ "$(uname -s)" = "Linux" ] || { printf '%s this only runs on Linux\n' "$(red fail)"; exit 2; }
command -v "$QS" >/dev/null || { printf '%s %s not found on PATH\n' "$(red fail)" "$QS"; exit 2; }
command -v timeout >/dev/null || { printf '%s coreutils timeout not found\n' "$(red fail)"; exit 2; }
[ -d "$BUILD_DIR/qml" ] || {
    printf '%s %s/qml missing - build first:\n' "$(red fail)" "$BUILD_DIR"
    printf '      cmake -B build -G Ninja && cmake --build build\n'
    exit 2
}

mkdir -p "$LOG_DIR"

# --------------------------------------------------------------- compositor

COMP_PID=""
COMP_DIR=""
SOCKET=""
SIG=""

cleanup() {
    if [ -n "$COMP_PID" ] && kill -0 "$COMP_PID" 2>/dev/null; then
        kill -TERM "-$COMP_PID" 2>/dev/null || kill -TERM "$COMP_PID" 2>/dev/null
        for _ in $(seq 1 20); do kill -0 "$COMP_PID" 2>/dev/null || break; sleep 0.25; done
        kill -KILL "-$COMP_PID" 2>/dev/null
    fi
    [ -n "$COMP_DIR" ] && rm -rf "$COMP_DIR"
}
trap cleanup EXIT INT TERM

start_compositor() {
    command -v Hyprland >/dev/null || {
        printf '%s Hyprland not found, and no SMOKE_SOCKET given.\n' "$(red fail)"
        printf '      The shell needs a wlr-layer-shell compositor to instantiate PanelWindow.\n'
        exit 2
    }

    COMP_DIR=$(mktemp -d)
    cat > "$COMP_DIR/hyprland.conf" <<'EOF'
monitor = ,1920x1080@60,0x0,1
animations { enabled = false }
decoration { blur { enabled = false } shadow { enabled = false } }
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_autoreload = true
}
EOF

    local before after
    before=$(ls "$RUNTIME" 2>/dev/null | grep -E '^wayland-[0-9]+$' | sort)

    setsid env XDG_RUNTIME_DIR="$RUNTIME" \
        Hyprland --config "$COMP_DIR/hyprland.conf" > "$COMP_DIR/compositor.log" 2>&1 &
    COMP_PID=$!

    for _ in $(seq 1 40); do
        after=$(ls "$RUNTIME" 2>/dev/null | grep -E '^wayland-[0-9]+$' | sort)
        SOCKET=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -1)
        [ -n "$SOCKET" ] && break
        kill -0 "$COMP_PID" 2>/dev/null || break
        sleep 0.5
    done

    [ -n "$SOCKET" ] || {
        printf '%s nested compositor failed to start\n' "$(red fail)"
        tail -15 "$COMP_DIR/compositor.log" | sed 's/^/      /'
        exit 2
    }
    SIG=$(ls -t "$RUNTIME/hypr" 2>/dev/null | head -1)
}

if [ -n "${SMOKE_SOCKET:-}" ]; then
    [ "$SMOKE_SOCKET" = "${WAYLAND_DISPLAY:-}" ] && {
        printf '%s SMOKE_SOCKET is your live session (%s). Refusing - the shell would\n' "$(red fail)" "$SMOKE_SOCKET"
        printf '      draw over your desktop and fight the running one for layer surfaces.\n'
        exit 2
    }
    SOCKET=$SMOKE_SOCKET
    SIG=${SMOKE_HYPR_SIG:-${HYPRLAND_INSTANCE_SIGNATURE:-}}
    printf 'using provided compositor: %s\n' "$SOCKET"
else
    printf 'starting nested compositor... '
    start_compositor
    printf 'up on %s\n' "$SOCKET"
fi

# ------------------------------------------------------------------- presets

presets=()
if [ ${#WANTED[@]} -gt 0 ]; then
    for w in "${WANTED[@]}"; do
        if   [ -f "$w" ];                  then presets+=("$w")
        elif [ -f "$PRESET_DIR/$w.json" ]; then presets+=("$PRESET_DIR/$w.json")
        else printf '%s no such preset: %s\n' "$(red fail)" "$w" >&2; exit 2
        fi
    done
else
    while IFS= read -r p; do presets+=("$p"); done < <(find "$PRESET_DIR" -maxdepth 1 -name '*.json' | sort)
fi
[ ${#presets[@]} -gt 0 ] || { printf '%s no presets in %s\n' "$(red fail)" "$PRESET_DIR"; exit 2; }

printf 'smoke matrix: %d preset(s), %ss window each\n\n' "${#presets[@]}" "$TIMEOUT_S"

filter_ignored() {
    if [ -s "$IGNORE_FILE" ] && grep -qEv '^[[:space:]]*(#|$)' "$IGNORE_FILE" 2>/dev/null; then
        grep -Ev -f <(grep -Ev '^[[:space:]]*(#|$)' "$IGNORE_FILE") || true
    else
        cat
    fi
}

# ----------------------------------------------------------------------- run

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
    XDG_RUNTIME_DIR="$RUNTIME" \
    WAYLAND_DISPLAY="$SOCKET" \
    HYPRLAND_INSTANCE_SIGNATURE="$SIG" \
    QT_QPA_PLATFORM=wayland \
    QS_NO_RELOAD_POPUP=1 \
    QML2_IMPORT_PATH="$BUILD_DIR/qml:${QML2_IMPORT_PATH:-}" \
        timeout -s TERM "$TIMEOUT_S" "$QS" -p "$ROOT" >"$log" 2>&1
    rc=$?

    # rc 124 == still alive when we killed it == booted and stayed up. That is success.
    if [ $rc -ne 124 ]; then
        printf '%s  (exited early, rc=%d)\n' "$(red FAIL)" "$rc"
        strip < "$log" | grep -E 'ERROR|error' | head -12 | sed 's/^/        /'
        failures=$((failures + 1))
        rm -rf "$cfg"
        continue
    fi

    hard=$(strip < "$log" | grep -E '(^|\s)ERROR' | filter_ignored || true)
    soft=$(strip < "$log" | grep -E '(^|\s)WARN'  | filter_ignored || true)

    if [ -n "$hard" ] || [ -n "$soft" ]; then
        printf '%s\n' "$(red FAIL)"
        [ -n "$hard" ] && printf '%s\n' "$hard" | head -15 | sed 's/^/        /'
        [ -n "$soft" ] && printf '%s\n' "$soft" | head -15 | sed 's/^/        /'
        failures=$((failures + 1))

        if [ "$BASELINE" = 1 ]; then
            {
                printf '\n# --- baselined from preset %s on %s ---\n' "$name" "$(date -Is)"
                printf '%s\n%s\n' "$hard" "$soft" \
                    | sed -E 's/^[[:space:]]+//' \
                    | sed -E 's/[][(){}.*+?^$|\\]/\\&/g' \
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
    printf '%s baseline written to %s\n' "$(yellow note)" "${IGNORE_FILE#$ROOT/}"
    printf '     READ IT. Delete every line that is a real bug rather than environment noise.\n'
    exit 0
fi

if [ "$failures" -gt 0 ]; then
    printf '%s %d/%d preset(s) failed' "$(red FAIL)" "$failures" "${#presets[@]}"
    [ "$KEEP_LOGS" = 1 ] && printf ' - logs in %s' "${LOG_DIR#$ROOT/}"
    printf '\n'
    exit 1
fi

printf '%s all %d preset(s) booted clean\n' "$(green PASS)" "${#presets[@]}"
