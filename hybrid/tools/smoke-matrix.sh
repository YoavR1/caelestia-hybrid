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
#   ./hybrid/tools/smoke-matrix.sh --compositor sway  # headless sway, for CI
#   ./hybrid/tools/smoke-matrix.sh --no-interact      # boot only, no IPC drive
#   ./hybrid/tools/smoke-matrix.sh --self-test        # prove the gate can still fail
#
# Env:
#   BUILD_DIR    default ./build
#   QS           quickshell binary, default `qs`
#   SWAY         sway binary, default `sway`
#   SMOKE_SOCKET pre-existing WAYLAND_DISPLAY to test against instead of spawning
#                a nested compositor. Must NOT be your live session (see below).
#
# WHY A COMPOSITOR: Quickshell's PanelWindow is a wlr-layer-shell surface. Without a
# Wayland backend it is unavailable, and the failure poisons the whole singleton graph
# ("No PanelWindow backend loaded"). QT_QPA_PLATFORM=offscreen therefore CANNOT boot
# this shell. Upstream's lint.yml runs an offscreen `qs` only to emit .qmlls.ini for the
# linter -- its exit code is never checked. So we spawn a nested Hyprland instead.
#
# HYPRLAND vs SWAY: Hyprland has no headless backend it will select on its own -- with no
# parent Wayland or X11 display and no free DRM node it dies with `CBackend::create()
# failed!`, and neither XDG_BACKEND nor WLR_BACKENDS changes that (aquamarine's headless
# backend is a fallback for output management, not something you can ask for). So it cannot
# run in a CI container. Headless sway can: it is wlroots, it implements wlr-layer-shell,
# and `WLR_BACKENDS=headless WLR_RENDERER=pixman` needs no GPU at all. Without the pixman
# renderer the shell loads and then dies on `importing the supplied dmabufs failed` ->
# `Could not create EGL surface` -> Wayland protocol error.
#
# Hyprland is still the default where it can run, because sway loses everything that goes
# through Hyprland IPC -- including the lua/conf axis below. The sway run is a narrower
# gate: it still catches load errors, missing types and binding errors across every preset,
# which is most of what this is for. Its extra environment noise lives in a separate
# smoke-ignore-sway.txt so the Hyprland gate stays strict.
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
# BOOTING IS NOT ENOUGH. After the shell comes up, every drawer is opened and closed over
# its own IPC, the launcher is sent to its emoji and clipboard modes, a toast is raised and
# Nexus is opened. The first run of this found two errors that fifteen boots had not:
# `Paths is not defined` in the emoji list (an import removed by the Phase 0 unused-import
# sweep -- trap T16), and `Unable to assign ConfigRoot` in PageBase, which left targetConfig
# null on every settings page after the Phase 2 merge. Neither is reachable at boot.
#
# --no-interact skips it, which is only worth doing while bisecting a boot failure.
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
SWAY=${SWAY:-sway}
PRESET_DIR=$ROOT/hybrid/presets
SELF_TEST=0
IGNORE_FILE=$ROOT/hybrid/tools/smoke-ignore.txt
IGNORE_HEADLESS=$ROOT/hybrid/tools/smoke-ignore-headless.txt
LOG_DIR=$ROOT/.smoke-logs
# A CI container has no XDG_RUNTIME_DIR and no /run/user/<uid>. Wayland needs one, so
# make a private one rather than failing in the compositor with something obscure.
RUNTIME=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
RUNTIME_TMP=""
if [ ! -d "$RUNTIME" ]; then
    RUNTIME_TMP=$(mktemp -d)
    chmod 700 "$RUNTIME_TMP"
    RUNTIME=$RUNTIME_TMP
    export XDG_RUNTIME_DIR="$RUNTIME"
fi

TIMEOUT_S=15
KEEP_LOGS=0
BASELINE=0
INTERACT=1
HYPR_FMTS=(lua)
COMPOSITOR=auto
WANTED=()

while [ $# -gt 0 ]; do
    case $1 in
        --timeout)   TIMEOUT_S=$2; shift 2 ;;
        --keep-logs) KEEP_LOGS=1; shift ;;
        --baseline)  BASELINE=1; KEEP_LOGS=1; shift ;;
        --no-interact) INTERACT=0; shift ;;
        --self-test)   SELF_TEST=1; shift ;;
        --compositor)
            case $2 in
                hyprland|sway|auto) COMPOSITOR=$2 ;;
                *) printf 'unknown --compositor value: %s (want hyprland, sway or auto)\n' "$2" >&2; exit 2 ;;
            esac
            shift 2 ;;
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
    [ -n "$RUNTIME_TMP" ] && rm -rf "$RUNTIME_TMP"
}
trap cleanup EXIT INT TERM

# Sway is the CI path: wlroots, real wlr-layer-shell, and a headless backend that needs
# no GPU. It knows nothing about Hyprland IPC, so it is a narrower gate -- see the header.
start_sway() {
    command -v "$SWAY" >/dev/null || {
        printf '%s %s not found.\n' "$(red fail)" "$SWAY"
        exit 2
    }

    COMP_DIR=$(mktemp -d)
    printf 'output HEADLESS-1 mode 1920x1080@60Hz\ndefault_border none\n' > "$COMP_DIR/sway.conf"

    local before after
    before=$(ls "$RUNTIME" 2>/dev/null | grep -E '^wayland-[0-9]+$' | sort)

    # pixman, not the GL renderer: a headless output has no scanout buffer, so Qt's EGL
    # surface creation fails and the client is killed with a Wayland protocol error.
    env -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$RUNTIME" \
        WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman \
        setsid "$SWAY" -c "$COMP_DIR/sway.conf" > "$COMP_DIR/compositor.log" 2>&1 &
    COMP_PID=$!

    for _ in $(seq 1 40); do
        after=$(ls "$RUNTIME" 2>/dev/null | grep -E '^wayland-[0-9]+$' | sort)
        SOCKET=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -1)
        [ -n "$SOCKET" ] && break
        kill -0 "$COMP_PID" 2>/dev/null || break
        sleep 0.5
    done

    [ -n "$SOCKET" ] || {
        printf '%s headless sway failed to start\n' "$(red fail)"
        tail -15 "$COMP_DIR/compositor.log" | sed 's/^/      /'
        exit 2
    }
    SIG=""
}

start_compositor() {
    command -v Hyprland >/dev/null || {
        printf '%s Hyprland not found, and no SMOKE_SOCKET given.\n' "$(red fail)"
        printf '      The shell needs a wlr-layer-shell compositor to instantiate PanelWindow.\n'
        printf '      Headless sway works too:  --compositor sway\n'
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

# A gate nobody has watched fail is not known to work. Two in this project turned out to
# have no teeth -- build.yml's -Werror legs, which had never been run, and a hand-rolled
# gate script that printed diagnostic counts without ever setting its failure flag. This
# feeds the harness a config that is valid JSON and invalid schema, and passes only when
# the run FAILS. Every line below is a different rejection path in settings::Node.
if [ "$SELF_TEST" = 1 ]; then
    POISON=$(mktemp -t smoke-selftest-XXXXXX.json)
    cat > "$POISON" <<'JSON'
{
  "hybrid": {
    "preset": "recomended",
    "featurez": { "dock": false },
    "features": { "dokc": false, "clipboard": "not-a-boolean" }
  },
  "totallyBogusTopLevelKey": { "nope": 1 }
}
JSON
    presets=("$POISON")
    printf '%s self-test: expecting this run to FAIL\n\n' "$(yellow note)"
fi

filter_ignored() {
    local files=("$IGNORE_FILE")
    # Sway is not Hyprland and a CI container has no GPU, PipeWire or session bus. That
    # noise is environmental *there* and a real signal under Hyprland, so it is a separate
    # list rather than more entries in the main one.
    [ "$COMPOSITOR" = sway ] && files+=("$IGNORE_HEADLESS")
    local pats
    pats=$(cat "${files[@]}" 2>/dev/null | grep -Ev '^[[:space:]]*(#|$)' || true)
    if [ -n "$pats" ]; then
        grep -Ev -f <(printf '%s\n' "$pats") || true
    else
        cat
    fi
}

# ----------------------------------------------------------------------- run

failures=0
runs=0

# Open and close everything the shell exposes over IPC. Failures here are ignored on
# purpose: a drawer that a preset has switched off simply does nothing, and the log is what
# is being measured, not these exit codes.
drive_shell() {
    local -a env=("$@")
    local ipc=(env "${env[@]}" "$QS" -p "$ROOT" ipc call)

    sleep 6   # let the shell finish loading before poking it

    for drawer in dashboard launcher session sidebar utilities workspaceDrawer osd; do
        "${ipc[@]}" drawers toggle "$drawer" >/dev/null 2>&1
        sleep 0.9
        "${ipc[@]}" drawers toggle "$drawer" >/dev/null 2>&1
        sleep 0.4
    done

    for mode in openEmoji openClipboard; do
        "${ipc[@]}" launcher "$mode" >/dev/null 2>&1
        sleep 1.2
        "${ipc[@]}" drawers toggle launcher >/dev/null 2>&1
        sleep 0.4
    done

    "${ipc[@]}" toaster info "smoke" "interaction pass" "info" >/dev/null 2>&1
    sleep 0.6

    # Every settings page, not just the first. This is where the null targetConfig lived,
    # and 16 pages of UI that nothing renders is 16 pages nothing checks.
    local pages
    pages=$(grep -c 'label: qsTr' "$ROOT/modules/nexus/PageRegistry.qml" 2>/dev/null || echo 1)
    for ((i = 0; i < pages; i++)); do
        "${ipc[@]}" nexus openPage "$i" >/dev/null 2>&1
        sleep 0.7
    done
    sleep 1

    # The lock screen is a large surface nothing else reaches. It locks the *nested*
    # compositor, never a real session -- the harness refuses to run against one.
    "${ipc[@]}" lock lock >/dev/null 2>&1
    sleep 2.5
    "${ipc[@]}" lock unlock >/dev/null 2>&1
    sleep 1.5

    for picker in open openFreeze openClip; do
        "${ipc[@]}" picker "$picker" >/dev/null 2>&1
        sleep 0.8
    done

    "${ipc[@]}" idleInhibitor toggle >/dev/null 2>&1
    sleep 0.4
    "${ipc[@]}" idleInhibitor toggle >/dev/null 2>&1
    "${ipc[@]}" audio cycleOutput >/dev/null 2>&1
    "${ipc[@]}" brightness get >/dev/null 2>&1
    sleep 1.5
}

run_preset() {
    local preset=$1 label=$2 name log cfg rc hard soft
    name=$(basename "$preset" .json)
    log=$LOG_DIR/${name}${label:+.$label}.log
    cfg=$(mktemp -d)
    mkdir -p "$cfg/caelestia"
    cp "$preset" "$cfg/caelestia/shell.json"
    runs=$((runs + 1))

    printf '  %-16s ' "$name"

    local -a env=(
        XDG_CONFIG_HOME="$cfg"
        XDG_CACHE_HOME="$cfg/cache"
        XDG_STATE_HOME="$cfg/state"
        XDG_RUNTIME_DIR="$RUNTIME"
        WAYLAND_DISPLAY="$SOCKET"
        HYPRLAND_INSTANCE_SIGNATURE="$SIG"
        QT_QPA_PLATFORM=wayland
        QS_NO_RELOAD_POPUP=1
        QML2_IMPORT_PATH="$BUILD_DIR/qml:${QML2_IMPORT_PATH:-}"
    )

    if [ "$INTERACT" = 1 ]; then
        env "${env[@]}" "$QS" -p "$ROOT" >"$log" 2>&1 &
        local qspid=$!
        drive_shell "${env[@]}"
        if kill -0 "$qspid" 2>/dev/null; then
            kill -TERM "$qspid" 2>/dev/null
            wait "$qspid" 2>/dev/null
            rc=124   # still up when we asked it to stop, same meaning as timeout's
        else
            wait "$qspid" 2>/dev/null
            rc=$?
        fi
    else
        env "${env[@]}" timeout -s TERM "$TIMEOUT_S" "$QS" -p "$ROOT" >"$log" 2>&1
        rc=$?
    fi

    # rc 124 == still alive when we asked it to stop == booted and stayed up. Success.
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
    printf 'smoke matrix: %d preset(s), %s\n\n' "${#presets[@]}" \
        "$([ "$INTERACT" = 1 ] && printf 'boot + IPC drive' || printf "${TIMEOUT_S}s window each")"
    for preset in "${presets[@]}"; do run_preset "$preset" ""; done
else
    if [ "$COMPOSITOR" = auto ]; then
        if command -v Hyprland >/dev/null && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
            COMPOSITOR=hyprland
        elif command -v "$SWAY" >/dev/null; then
            COMPOSITOR=sway
            printf '%s no display to nest Hyprland in; falling back to headless sway\n' "$(yellow note)"
        else
            COMPOSITOR=hyprland   # let start_compositor print the real error
        fi
    fi

    if [ "$COMPOSITOR" = sway ]; then
        printf 'starting headless sway... '
        start_sway
        printf 'up on %s\n' "$SOCKET"
        printf 'smoke matrix: %d preset(s), %s\n\n' "${#presets[@]}" \
        "$([ "$INTERACT" = 1 ] && printf 'boot + IPC drive' || printf "${TIMEOUT_S}s window each")"
        for preset in "${presets[@]}"; do run_preset "$preset" "sway"; done
        cleanup
        COMP_PID=""; COMP_DIR=""; SOCKET=""; SIG=""
    else
        for fmt in "${HYPR_FMTS[@]}"; do
            printf 'starting nested Hyprland (%s config)... ' "$fmt"
            start_compositor "$fmt"
            printf 'up on %s\n' "$SOCKET"
            printf 'smoke matrix: %d preset(s), %s\n\n' "${#presets[@]}" \
        "$([ "$INTERACT" = 1 ] && printf 'boot + IPC drive' || printf "${TIMEOUT_S}s window each")"
            for preset in "${presets[@]}"; do
                run_preset "$preset" "$([ ${#HYPR_FMTS[@]} -gt 1 ] && printf '%s' "$fmt")"
            done
            cleanup
            COMP_PID=""; COMP_DIR=""; SOCKET=""; SIG=""
            echo
        done
    fi
fi

echo
if [ "$BASELINE" = 1 ]; then
    printf '%s baseline written to %s\n' "$(yellow note)" "${IGNORE_FILE#$ROOT/}"
    printf '     READ IT. Delete every line that is a real bug rather than environment noise.\n'
    exit 0
fi

if [ "$SELF_TEST" = 1 ]; then
    rm -f "$POISON"
    if [ "$failures" -gt 0 ]; then
        printf '%s self-test: the harness rejected a schema-invalid config, as it should\n' "$(green PASS)"
        exit 0
    fi
    printf '%s self-test: a schema-invalid config PASSED. The gate has no teeth --\n' "$(red FAIL)"
    printf '     it would report clean on presets the shell never actually loaded.\n'
    exit 1
fi

if [ "$failures" -gt 0 ]; then
    printf '%s %d/%d run(s) failed' "$(red FAIL)" "$failures" "$runs"
    [ "$KEEP_LOGS" = 1 ] && printf ' - logs in %s' "${LOG_DIR#$ROOT/}"
    printf '\n'
    exit 1
fi

printf '%s all %d run(s) clean\n' "$(green PASS)" "$runs"
