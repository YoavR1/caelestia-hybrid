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
#   ./hybrid/tools/smoke-matrix.sh --hypr both        # under both compositor configs
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
# LUA vs CONF: Hyprland 0.56 reads a Lua config if it finds one and calls the ini format
# "legacy" in its own logs, so the nested compositor uses Lua by default.
#
# This is a real axis, not a cosmetic one. Measured on Hyprland 0.56.2:
#
#   hyprctl dispatch workspace 2          -> error under a lua config
#   hyprctl keyword general:gaps_in 7     -> "keyword can't work with non-legacy parsers"
#   hyprctl dispatch 'hl.dsp.focus(...)'  -> ok
#
# and the shell branches on `Hyprland.usingLua` in 40 places across 17 files to pick a
# spelling. Booting under a lua config makes the shell see `usingLua == true`; under a
# conf config, false. `--hypr conf` and `--hypr both` keep the legacy half reachable.
#
# What this does NOT buy: nearly all 40 sites sit in click handlers, so a boot smoke
# reaches very few of them whichever config is used. Closing that gap needs interaction
# tests. See trap T17 for what booting under lua *does* expose.
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
HYPR_FMTS=(lua)
WANTED=()

while [ $# -gt 0 ]; do
    case $1 in
        --timeout)   TIMEOUT_S=$2; shift 2 ;;
        --keep-logs) KEEP_LOGS=1; shift ;;
        --baseline)  BASELINE=1; KEEP_LOGS=1; shift ;;
        --hypr)
            case $2 in
                lua|conf) HYPR_FMTS=("$2") ;;
                both)     HYPR_FMTS=(lua conf) ;;
                *) printf 'unknown --hypr value: %s (want lua, conf or both)\n' "$2" >&2; exit 2 ;;
            esac
            shift 2 ;;
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
    local cfg
    if [ "$1" = lua ]; then
        cfg=$COMP_DIR/hyprland.lua
        cat > "$cfg" <<'EOF'
hl.monitor({ output = "", mode = "1920x1080@60", position = "0x0", scale = 1 })

hl.config({
    animations = { enabled = false },
    decoration = {
        blur = { enabled = false },
        shadow = { enabled = false },
    },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        disable_autoreload = true,
    },
})
EOF
    else
        cfg=$COMP_DIR/hyprland.conf
        cat > "$cfg" <<'EOF'
monitor = ,1920x1080@60,0x0,1
animations { enabled = false }
decoration { blur { enabled = false } shadow { enabled = false } }
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_autoreload = true
}
EOF
    fi

    # Catch a config the running Hyprland cannot read before spending 20s on a
    # start that would fail with a much less obvious message.
    Hyprland --verify-config --config "$cfg" 2>&1 | grep -q '^config ok' || {
        printf '%s Hyprland rejected the %s config\n' "$(red fail)" "$1"
        Hyprland --verify-config --config "$cfg" 2>&1 | tail -10 | sed 's/^/      /'
        exit 2
    }

    local before after
    before=$(ls "$RUNTIME" 2>/dev/null | grep -E '^wayland-[0-9]+$' | sort)

    setsid env XDG_RUNTIME_DIR="$RUNTIME" \
        Hyprland --config "$cfg" > "$COMP_DIR/compositor.log" 2>&1 &
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

filter_ignored() {
    if [ -s "$IGNORE_FILE" ] && grep -qEv '^[[:space:]]*(#|$)' "$IGNORE_FILE" 2>/dev/null; then
        grep -Ev -f <(grep -Ev '^[[:space:]]*(#|$)' "$IGNORE_FILE") || true
    else
        cat
    fi
}

# ----------------------------------------------------------------------- run

failures=0
runs=0

run_preset() {
    local preset=$1 label=$2 name log cfg rc hard soft
    name=$(basename "$preset" .json)
    log=$LOG_DIR/${name}${label:+.$label}.log
    cfg=$(mktemp -d)
    mkdir -p "$cfg/caelestia"
    cp "$preset" "$cfg/caelestia/shell.json"
    runs=$((runs + 1))

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
        return
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
}

if [ -n "${SMOKE_SOCKET:-}" ]; then
    [ "$SMOKE_SOCKET" = "${WAYLAND_DISPLAY:-}" ] && {
        printf '%s SMOKE_SOCKET is your live session (%s). Refusing - the shell would\n' "$(red fail)" "$SMOKE_SOCKET"
        printf '      draw over your desktop and fight the running one for layer surfaces.\n'
        exit 2
    }
    [ ${#HYPR_FMTS[@]} -gt 1 ] && {
        printf '%s --hypr both needs to start its own compositors; SMOKE_SOCKET gives one.\n' "$(red fail)"
        exit 2
    }
    SOCKET=$SMOKE_SOCKET
    SIG=${SMOKE_HYPR_SIG:-${HYPRLAND_INSTANCE_SIGNATURE:-}}
    printf 'using provided compositor: %s\n' "$SOCKET"
    printf 'smoke matrix: %d preset(s), %ss window each\n\n' "${#presets[@]}" "$TIMEOUT_S"
    for preset in "${presets[@]}"; do run_preset "$preset" ""; done
else
    for fmt in "${HYPR_FMTS[@]}"; do
        printf 'starting nested compositor (%s config)... ' "$fmt"
        start_compositor "$fmt"
        printf 'up on %s\n' "$SOCKET"
        printf 'smoke matrix: %d preset(s), %ss window each\n\n' "${#presets[@]}" "$TIMEOUT_S"
        for preset in "${presets[@]}"; do
            run_preset "$preset" "$([ ${#HYPR_FMTS[@]} -gt 1 ] && printf '%s' "$fmt")"
        done
        cleanup
        COMP_PID=""; COMP_DIR=""; SOCKET=""; SIG=""
        echo
    done
fi

echo
if [ "$BASELINE" = 1 ]; then
    printf '%s baseline written to %s\n' "$(yellow note)" "${IGNORE_FILE#$ROOT/}"
    printf '     READ IT. Delete every line that is a real bug rather than environment noise.\n'
    exit 0
fi

if [ "$failures" -gt 0 ]; then
    printf '%s %d/%d run(s) failed' "$(red FAIL)" "$failures" "$runs"
    [ "$KEEP_LOGS" = 1 ] && printf ' - logs in %s' "${LOG_DIR#$ROOT/}"
    printf '\n'
    exit 1
fi

printf '%s all %d run(s) booted clean\n' "$(green PASS)" "$runs"
