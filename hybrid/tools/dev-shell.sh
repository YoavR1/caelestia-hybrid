#!/usr/bin/env bash
# Run the development shell in an isolated config, without touching the installed one.
#
#   ./hybrid/tools/dev-shell.sh                     # isolated, seeded from 'recommended'
#   ./hybrid/tools/dev-shell.sh --preset midnight
#   ./hybrid/tools/dev-shell.sh --config ~/some/shell.json
#   ./hybrid/tools/dev-shell.sh --offscreen         # headless, for a quick sanity boot
#   ./hybrid/tools/dev-shell.sh --reset             # wipe the DEV config only, then run
#
# Why this exists: configDir() is hardcoded to $XDG_CONFIG_HOME/caelestia (trap T4), so
# installing to a differently-named quickshell directory does NOT isolate settings. This
# script overrides XDG_CONFIG_HOME so the dev instance cannot touch ~/.config/caelestia.
#
# This script never kills, installs, or overwrites anything outside its own dev directory.

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
ROOT=$PWD

DEV_HOME=${CAELESTIA_DEV_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/caelestia-hybrid-dev}
BUILD_DIR=${BUILD_DIR:-$ROOT/build}
QS=${QS:-qs}
PRESET=recommended
CONFIG_SRC=
OFFSCREEN=0
RESET=0

while [ $# -gt 0 ]; do
    case $1 in
        --preset)    PRESET=$2; shift 2 ;;
        --config)    CONFIG_SRC=$2; shift 2 ;;
        --offscreen) OFFSCREEN=1; shift ;;
        --reset)     RESET=1; shift ;;
        -h|--help)   sed -n '2,16p' "$0"; exit 0 ;;
        *)           printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done

red()    { printf '\033[1;31m%s\033[0m' "$*"; }
yellow() { printf '\033[1;33m%s\033[0m' "$*"; }
blue()   { printf '\033[1;34m%s\033[0m' "$*"; }

[ "$(uname -s)" = "Linux" ] || { printf '%s Quickshell only runs on Linux\n' "$(red fail)"; exit 2; }
command -v "$QS" >/dev/null || { printf '%s %s not found on PATH\n' "$(red fail)" "$QS"; exit 2; }
[ -d "$BUILD_DIR/qml" ] || {
    printf '%s %s/qml missing — build first:  cmake -B build -G Ninja && cmake --build build\n' "$(red fail)" "$BUILD_DIR"
    exit 2
}

CFG_HOME=$DEV_HOME/config
CFG_FILE=$CFG_HOME/caelestia/shell.json

if [ "$RESET" = 1 ]; then
    # Scoped to DEV_HOME only. Guard against a mis-set env var pointing at something real.
    case $DEV_HOME in
        */caelestia-hybrid-dev) printf '%s resetting %s\n' "$(blue ==\>)" "$DEV_HOME"; rm -rf "$DEV_HOME" ;;
        *) printf '%s CAELESTIA_DEV_HOME does not end in caelestia-hybrid-dev; refusing to --reset %s\n' "$(red fail)" "$DEV_HOME"; exit 2 ;;
    esac
fi

mkdir -p "$CFG_HOME/caelestia" "$DEV_HOME/cache" "$DEV_HOME/state"

if [ ! -f "$CFG_FILE" ]; then
    if [ -n "$CONFIG_SRC" ]; then
        src=$CONFIG_SRC
    else
        src=$ROOT/hybrid/presets/$PRESET.json
    fi
    [ -f "$src" ] || { printf '%s no such config: %s\n' "$(red fail)" "$src"; exit 2; }
    cp "$src" "$CFG_FILE"
    printf '%s seeded dev config from %s\n' "$(blue ==\>)" "${src#$ROOT/}"
elif [ -n "$CONFIG_SRC" ]; then
    cp "$CONFIG_SRC" "$CFG_FILE"
    printf '%s overwrote dev config from %s\n' "$(blue ==\>)" "$CONFIG_SRC"
fi

# Report, never act. The user's running shell is theirs.
if pgrep -x quickshell >/dev/null 2>&1; then
    printf '%s a quickshell process is already running.\n' "$(yellow note)"
    printf '     This dev instance uses its own config and will not touch it, but the two may\n'
    printf '     compete for layer-shell surfaces and global shortcuts. That is cosmetic.\n'
    printf '     Stop this dev instance with Ctrl-C. Do not killall.\n\n'
fi

printf '%s config   %s\n' "$(blue ==\>)" "$CFG_FILE"
printf '%s shell    %s\n' "$(blue ==\>)" "$ROOT"
printf '%s stop     Ctrl-C\n\n' "$(blue ==\>)"

export XDG_CONFIG_HOME="$CFG_HOME"
export XDG_CACHE_HOME="$DEV_HOME/cache"
export XDG_STATE_HOME="$DEV_HOME/state"
export QML2_IMPORT_PATH="$BUILD_DIR/qml:${QML2_IMPORT_PATH:-}"
[ "$OFFSCREEN" = 1 ] && export QT_QPA_PLATFORM=offscreen

exec "$QS" -p "$ROOT"
