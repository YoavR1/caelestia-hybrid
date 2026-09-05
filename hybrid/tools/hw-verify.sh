#!/usr/bin/env bash
# On-hardware verification, for the half of the shell a headless boot cannot reach.
#
# `smoke-matrix.sh` proves every preset loads without QML errors. It cannot move a
# cursor, press a key, or see a panel, so it is blind to the entire class of bug
# where a feature loads correctly and is then unreachable -- which is exactly what
# T54 was: a dock whose show path did not exist, behind gates that all evaluated
# correctly, in a tree where every static gate passed.
#
# Run this ON the machine running the shell, in its Wayland session:
#   ./hybrid/tools/hw-verify.sh
#
# It only reads state and moves the pointer. It starts nothing and kills nothing.
set -uo pipefail

export LANG=${LANG:-C.UTF-8}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
: "${HYPRLAND_INSTANCE_SIGNATURE:=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QS_SEL=(-c caelestia)
[ -n "${HW_VERIFY_PATH:-}" ] && QS_SEL=(-p "$HW_VERIFY_PATH")

PASS=0; FAIL=0; SKIP=0
G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[0;33m'; N=$'\033[0m'

ipc()    { qs "${QS_SEL[@]}" ipc call "$@" 2>/dev/null; }
isopen() { ipc drawers isOpen "$1"; }
warp()   { hyprctl dispatch "hl.dsp.cursor.move({x=$1, y=$2})" >/dev/null 2>&1; }
global() { hyprctl dispatch "hl.dsp.global(\"caelestia:$1\")" >/dev/null 2>&1; }

ok()   { PASS=$((PASS+1)); printf "  %-34s ${G}ok${N} %s\n" "$1" "${2:-}"; }
bad()  { FAIL=$((FAIL+1)); printf "  %-34s ${R}FAIL${N} %s\n" "$1" "${2:-}"; }
skip() { SKIP=$((SKIP+1)); printf "  %-34s ${Y}skip${N} %s\n" "$1" "${2:-}"; }

# --- geometry ---------------------------------------------------------------
read -r MW MH MX MY < <(hyprctl monitors -j 2>/dev/null | python3 -c '
import json,sys
m=json.load(sys.stdin)[0]
print(m["width"],m["height"],m["x"],m["y"])' 2>/dev/null) || { echo "no monitor"; exit 2; }
CX=$((MX + MW/2)); BOTTOM=$((MY + MH - 2)); TOP=$((MY + 1))
RIGHT=$((MX + MW - 2)); MIDY=$((MY + MH/2)); PARK_X=$((MX + MW/2)); PARK_Y=$((MY + MH/2))

echo
echo "hw-verify: ${MW}x${MH} at ${MX},${MY}"
echo

# --- 1. instance sanity -----------------------------------------------------
echo "instance"
n=$(pgrep -x qs | wc -l)
if [ "$n" -eq 1 ]; then ok "exactly one shell running"
else bad "exactly one shell running" "found $n -- see T53"; fi

owner=$(busctl --user list 2>/dev/null | awk '$1=="org.freedesktop.Notifications"{print $2}')
me=$(pgrep -x qs | head -1)
if [ -n "$owner" ] && [ "$owner" = "$me" ]; then ok "owns org.freedesktop.Notifications"
elif [ -z "$owner" ]; then bad "owns org.freedesktop.Notifications" "nobody owns it"
else bad "owns org.freedesktop.Notifications" "owned by pid $owner, not $me -- T53"; fi

drawers=$(ipc drawers list | tr '\n' ' ')
if [ -n "$drawers" ]; then ok "drawers list answers" "($(echo "$drawers" | wc -w) keys)"
else bad "drawers list answers" "no response -- is the shell running?"; fi
echo

# --- 2. hover edges ---------------------------------------------------------
# The lock surface takes all pointer input, so every hover assertion below is
# meaningless while locked -- and it fails rather than erroring, which is the
# worst way to be wrong. Refuse instead (T23).
LOCKED=$(ipc lock isLocked)
HOVER_BLOCKED=0
[ "$LOCKED" = "true" ] && HOVER_BLOCKED=1

# showOnHover decides whether a panel responds to hover at all. Read the compiled
# default so this tracks the source, and let a user shell.json win.
CFG=$HOME/.config/caelestia/shell.json
hover_enabled() {
    local mod=$1 hpp="$ROOT/plugin/src/Caelestia/Config/${mod}config.hpp" def user
    def=$(grep -oP 'CONFIG_PROPERTY\(bool, showOnHover, \K(true|false)' "$hpp" 2>/dev/null | head -1)
    user=$(python3 -c 'import json,sys;d=json.load(open(sys.argv[1]));v=d.get(sys.argv[2],{}).get("showOnHover");print("" if v is None else str(v).lower())' "$CFG" "$mod" 2>/dev/null)
    [ -n "$user" ] && { echo "$user"; return; }
    echo "${def:-true}"
}

echo "hover edges"
[ "$HOVER_BLOCKED" = "1" ] && echo "  (screen is locked -- hover cannot be tested)"
hover_test() {
    local name=$1 x=$2 y=$3 settle=${4:-1.2} mod=${5:-$1}
    case " $drawers " in *" $name "*) ;; *) skip "$name opens on hover" "no such drawer"; return;; esac
    [ "$HOVER_BLOCKED" = "1" ] && { skip "$name opens on hover" "screen locked"; return; }
    if [ "$(hover_enabled "$mod")" != "true" ]; then
        skip "$name opens on hover" "$mod.showOnHover=false -- opens on drag"
        return
    fi
    warp "$PARK_X" "$PARK_Y"; sleep 0.6
    local before; before=$(isopen "$name")
    warp "$x" "$y"; sleep "$settle"
    local after; after=$(isopen "$name")
    warp "$PARK_X" "$PARK_Y"; sleep 0.6
    local back; back=$(isopen "$name")
    if [ "$after" = "1" ]; then
        if [ "$back" = "0" ]; then ok "$name opens on hover" "and closes on leave"
        else ok "$name opens on hover" "(stayed open on leave)"; fi
    else
        bad "$name opens on hover" "before=$before during=$after after=$back"
    fi
}
hover_test dock      "$CX"    "$BOTTOM"
hover_test dashboard "$CX"    "$TOP"
hover_test sidebar   "$RIGHT" "$MIDY"
echo

# --- 3. global shortcuts ----------------------------------------------------
echo "global shortcuts"
shortcut_test() {
    local name=$1 drawer=$2
    case " $drawers " in *" $drawer "*) ;; *) skip "$name -> $drawer" "no such drawer"; return;; esac
    local before; before=$(isopen "$drawer")
    global "$name"; sleep 1.0
    local after; after=$(isopen "$drawer")
    if [ "$after" != "$before" ] && [ -n "$after" ]; then
        global "$name"; sleep 0.6   # put it back
        ok "$name -> $drawer" "$before -> $after"
    else
        bad "$name -> $drawer" "stayed $before"
    fi
}
shortcut_test launcher          launcher
shortcut_test sidebar           sidebar
shortcut_test dashboard         dashboard
shortcut_test utilities         utilities
shortcut_test workspaceOverview workspaceDrawer
echo

# --- 4. nexus ---------------------------------------------------------------
echo "nexus"
before=$(hyprctl clients -j 2>/dev/null | python3 -c 'import json,sys; print(sum(1 for c in json.load(sys.stdin) if "nexus" in (c.get("title","")+c.get("class","")).lower()))' 2>/dev/null || echo 0)
ipc nexus open >/dev/null 2>&1; sleep 1.5
after=$(hyprctl clients -j 2>/dev/null | python3 -c 'import json,sys; print(sum(1 for c in json.load(sys.stdin) if "nexus" in (c.get("title","")+c.get("class","")).lower()))' 2>/dev/null || echo 0)
if [ "$after" -gt "$before" ]; then ok "nexus open creates a window" "$before -> $after"
else bad "nexus open creates a window" "$before -> $after"; fi
echo

# --- 5. notifications -------------------------------------------------------
echo "notifications"
if command -v notify-send >/dev/null; then
    notify-send "hw-verify" "probe $$" >/dev/null 2>&1
    sleep 1.2
    if [ "$(isopen dashboard)" != "unknown" ]; then ok "notify-send accepted" "(bus owner answered)"
    else bad "notify-send accepted"; fi
else skip "notify-send accepted" "notify-send missing"; fi
echo

warp "$PARK_X" "$PARK_Y"
printf "%s\n" "----"
if [ "$FAIL" -eq 0 ]; then printf "${G}PASS${N} %d ok, %d skipped\n" "$PASS" "$SKIP"; exit 0
else printf "${R}FAIL${N} %d failed, %d ok, %d skipped\n" "$FAIL" "$PASS" "$SKIP"; exit 1; fi
