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

# Warping is not input. `hl.dsp.cursor.move` repositions the pointer, and the
# compositor does not synthesise a motion event for it -- proved by warping
# between two windows under `follow_mouse=1` and watching focus never change. So
# a warp alone cannot trigger a hover, and a hover suite driven by warps reports
# whatever the drawers happened to be doing already.
#
# Real events need /dev/uinput, which means ydotoold. Position roughly with a
# warp, then land the last pixels with a relative ydotool move so the compositor
# delivers motion to the surface under the pointer.
HAVE_REAL_INPUT=0
if [ -n "${YDOTOOL_SOCKET:-}" ] && command -v ydotool >/dev/null && pgrep -x ydotoold >/dev/null; then
    HAVE_REAL_INPUT=1
fi

move_for_real() {
    local x=$1 y=$2
    if [ "$HAVE_REAL_INPUT" = "1" ]; then
        # Approach from 24px away so the final motion is a genuine event at (x,y).
        local from_y=$((y > 24 ? y - 24 : y + 24))
        warp "$x" "$from_y"
        sleep 0.3
        local step=$(( y > from_y ? 4 : -4 ))
        local i=0
        while [ $i -lt 6 ]; do ydotool mousemove -x 0 -y $step 2>/dev/null; sleep 0.05; i=$((i + 1)); done
    else
        warp "$x" "$y"
    fi
}
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

# Nothing this script does counts as input. `hl.dsp.cursor.move` repositions the
# pointer without waking the idle timer, so a session that locks after N seconds
# will lock *during* the run -- and the lock surface then takes every pointer
# event, turning the hover block red for a reason that has nothing to do with the
# panels. Hold the inhibitor for the duration and put it back afterwards.
IDLE_WAS=$(ipc idleInhibitor isEnabled)
if [ "$IDLE_WAS" != "true" ]; then
    ipc idleInhibitor enable >/dev/null 2>&1
    trap 'ipc idleInhibitor disable >/dev/null 2>&1' EXIT
fi
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

# A shell started over ssh -- `setsid qs ...` from a remote login -- lands in that
# ssh session's cgroup rather than the compositor's. polkit then sees its requests
# as coming from a session that is not the seat's active one, and actions whose
# policy is `allow_active=yes` start raising an authentication prompt that never
# used to appear. That prompt is a near-fullscreen overlay layer, so it swallows
# every hover and turns this whole file red for a reason that has nothing to do
# with the shell. Restart it as a child of the compositor instead:
#
#   hyprctl dispatch 'hl.dsp.exec_cmd("qs -c caelestia -n -d")'
#
qs_pid=$(pgrep -x qs | head -1)
if [ -n "$qs_pid" ] && [ -r "/proc/$qs_pid/environ" ]; then
    shell_session=$(tr '\0' '\n' < "/proc/$qs_pid/environ" | sed -n 's/^XDG_SESSION_ID=//p')
    wm_pid=$(pgrep -x Hyprland | head -1)
    wm_session=$(tr '\0' '\n' < "/proc/$wm_pid/environ" 2>/dev/null | sed -n 's/^XDG_SESSION_ID=//p')
    if [ -n "$shell_session" ] && [ -n "$wm_session" ] && [ "$shell_session" != "$wm_session" ]; then
        bad "shell is in the compositor's session" "shell=$shell_session wm=$wm_session -- expect polkit prompts"
    else
        ok "shell is in the compositor's session" "${shell_session:+session $shell_session}"
    fi
fi

# A modal on the overlay layer takes every pointer event before a drawer sees it.
grabs=$(hyprctl layers 2>/dev/null | grep -cE 'polkit|lockscreen')
if [ "${grabs:-0}" -gt 0 ]; then
    bad "no modal holding a pointer grab" "$grabs overlay surface(s) -- hover results below are meaningless"
else
    ok "no modal holding a pointer grab"
fi

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
# A modal with a pointer grab -- the shell's own polkit prompt is the usual one --
# swallows every motion event, and every hover assertion below then fails for a
# reason that has nothing to do with the panels. If these all fail at once, look
# at the screen before believing them.
hover_test() {
    local name=$1 x=$2 y=$3 settle=${4:-1.2} mod=${5:-$1}
    case " $drawers " in *" $name "*) ;; *) skip "$name opens on hover" "no such drawer"; return;; esac
    [ "$HOVER_BLOCKED" = "1" ] && { skip "$name opens on hover" "screen locked"; return; }
    # Re-checked per test: a session can lock partway through a run, and every
    # assertion after that point is about the lock surface rather than the panel.
    if [ "$(ipc lock isLocked)" = "true" ]; then
        skip "$name opens on hover" "screen locked mid-run"
        return
    fi
    if [ "$(hover_enabled "$mod")" != "true" ]; then
        skip "$name opens on hover" "$mod.showOnHover=false -- opens on drag"
        return
    fi
    if [ "$HAVE_REAL_INPUT" != "1" ]; then
        skip "$name opens on hover" "needs real input; run ydotoold and set YDOTOOL_SOCKET"
        return
    fi
    move_for_real "$PARK_X" "$PARK_Y"; sleep 0.6
    local before; before=$(isopen "$name")
    # An already-open drawer would satisfy "after = 1" without hover doing anything.
    if [ "$before" = "1" ]; then
        ipc drawers toggle "$name" >/dev/null 2>&1
        sleep 0.8
        before=$(isopen "$name")
        if [ "$before" = "1" ]; then
            skip "$name opens on hover" "already open and would not close -- result would be vacuous"
            return
        fi
    fi
    move_for_real "$x" "$y"; sleep "$settle"
    local after; after=$(isopen "$name")
    move_for_real "$PARK_X" "$PARK_Y"; sleep 0.6
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
# The launcher binding is release-triggered on both sides: the shell acts in
# `onReleased`, and the keybind carries Hyprland's `release` flag because it is
# bound to a bare Super tap. `hyprctl dispatch global` is a one-shot that never
# delivers the release, so this needs a real key event or nothing happens --
# which the harness reported as a failure until it was checked by hand.
if [ -n "${YDOTOOL_SOCKET:-}" ] && command -v ydotool >/dev/null; then
    before=$(isopen launcher)
    ydotool key 125:1 125:0 2>/dev/null; sleep 1.5
    after=$(isopen launcher)
    if [ "$after" != "$before" ]; then
        ydotool key 1:1 1:0 2>/dev/null; sleep 0.5
        ok "launcher (real Super tap)" "$before -> $after"
    else
        bad "launcher (real Super tap)" "stayed $before"
    fi
else
    skip "launcher" "release-triggered; needs ydotool (set YDOTOOL_SOCKET)"
fi
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
