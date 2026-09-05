#!/usr/bin/env bash
# Does a setting actually change anything? Write it, then observe the result.
#
# `hw-audit.sh` proves a setting can be changed without the shell complaining, and
# `settings-paths.sh` proves the path exists. Neither proves the value does anything,
# and that gap is exactly where T62 lived: the taskbar position wrote correctly to a
# layer nothing read, so every signal said success and the bar never moved. A user
# found it; no gate here could.
#
# This closes the gap for settings whose effect is observable from outside the shell.
# That is a real subset rather than all 372 keys -- most settings change pixels, and
# pixels are not assertable from a script. The subset is listed explicitly below, so
# what is covered is legible rather than implied.
#
# The main observable is Hyprland's `reserved` (left, top, right, bottom): the space
# layer surfaces claim. The bar's exclusive zone shows up there, which makes position,
# visibility and border thickness all measurable exactly.
#
#   ./hybrid/tools/hw-effects.sh            # run against the live session
#   ./hybrid/tools/hw-effects.sh --list     # print the cases and exit
set -uo pipefail

export LANG=${LANG:-C.UTF-8}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
: "${HYPRLAND_INSTANCE_SIGNATURE:=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE

CFG=${CAELESTIA_CONFIG:-$HOME/.config/caelestia/shell.json}
SETTLE=${SETTLE:-3}

G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[0;33m'; N=$'\033[0m'
PASS=0; FAIL=0; SKIP=0

# node | key | value (json) | expected reserved [l, t, r, b]
# Baseline for every case: bar.persistent=true, bar.position=top, border.thickness=10.
CASES=$(cat <<'EOP'
bar.position|"top"|reserved|[10, 60, 10, 10]|the bar reserves the top edge
bar.position|"bottom"|reserved|[10, 10, 10, 60]|the bar reserves the bottom edge
bar.position|"left"|reserved|[60, 10, 10, 10]|the bar reserves the left edge
bar.position|"right"|reserved|[10, 10, 60, 10]|the bar reserves the right edge
bar.persistent|false|reserved|[10, 10, 10, 10]|a non-persistent bar reserves nothing
border.thickness|24|reserved|[24, 88, 24, 24]|border thickness scales every edge
appearance.islands|true|reserved|[10, 88, 10, 10]|islands widens the bar's reserved zone
bar.excludedScreens|["LVDS-1"]|reserved|[10, 10, 10, 10]|an excluded screen gets no bar
background.wallpaperEnabled|false|layer:caelestia-background|level=1|no wallpaper drops the background out of the wallpaper layer
hybrid.features.floatingLyrics|false|layer:caelestia-desktopLyricsOverlay|absent|the lyrics overlay is not created when its feature is off
hybrid.features.floatingLyrics|true|layer:caelestia-desktopLyricsOverlay|level=3|and is created when it is on
EOP
)

if [ "${1:-}" = "--list" ]; then
    printf '%s\n' "$CASES" | while IFS='|' read -r path val obs exp desc; do
        [ -z "$path" ] && continue
        printf "  %-32s = %-14s  %-38s -> %-10s  %s\n" "$path" "$val" "$obs" "$exp" "$desc"
    done
    exit 0
fi

command -v hyprctl >/dev/null || { echo "hyprctl not found" >&2; exit 2; }
[ -f "$CFG" ] || { echo "no config at $CFG" >&2; exit 2; }
pgrep -x qs >/dev/null || { echo "no shell running" >&2; exit 2; }

# Two kinds of observable, both read from the compositor rather than from the shell:
#   reserved          the space layer surfaces claim, as [left, top, right, bottom]
#   layer:<namespace> the layer's level, or "absent" if it does not exist at all
observe() {
    case "$1" in
        reserved)
            hyprctl monitors -j 2>/dev/null |
                python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["reserved"])' ;;
        layer:*)
            hyprctl layers -j 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
for mon in json.load(sys.stdin).values():
    for level, layers in mon.get("levels", {}).items():
        for layer in layers:
            if (layer.get("namespace") or "") == want:
                print("level=" + level)
                sys.exit(0)
print("absent")
' "${1#layer:}" ;;
        *) echo "unknown observable: $1" >&2; return 1 ;;
    esac
}

# Takes a dotted path so nested nodes -- hybrid.features.floatingLyrics -- are reachable.
set_key() {
    python3 - "$CFG" "$1" "$2" <<'PY'
import json, sys
path, dotted, raw = sys.argv[1:4]
try:
    val = json.loads(raw)
except json.JSONDecodeError:
    val = raw
d = json.load(open(path))
node = d
*parents, leaf = dotted.split(".")
for part in parents:
    node = node.setdefault(part, {})
node[leaf] = val
json.dump(d, open(path, "w"), indent=2)
PY
}

backup=$(mktemp)
cp "$CFG" "$backup"
# Restore on any exit, including an interrupt: leaving someone's bar somewhere they
# did not put it is not an acceptable failure mode for a test.
trap 'cp "$backup" "$CFG"; rm -f "$backup"; sleep 1' EXIT

baseline() {
    set_key bar.persistent true
    set_key bar.position '"top"'
    set_key border.thickness 10
    set_key appearance.islands false
    set_key bar.excludedScreens '[]'
    set_key background.wallpaperEnabled true
    set_key hybrid.features.floatingLyrics true
    sleep "$SETTLE"
}

echo
echo "hw-effects: writing settings and observing the result"
baseline
start=$(observe reserved)
if [ "$start" != "[10, 10, 10, 10]" ] && [ "$start" != "[10, 60, 10, 10]" ]; then
    echo "  ${Y}note${N} baseline reserved is $start, not the expected [10, 60, 10, 10]"
fi
echo

MONITOR=$(hyprctl monitors -j | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["name"])')

while IFS='|' read -r path val obs exp desc; do
    [ -z "$path" ] && continue
    # The excludedScreens case names a monitor; use whichever one is actually here.
    case "$path" in *excludedScreens) val="[\"$MONITOR\"]" ;; esac
    baseline
    set_key "$path" "$val"
    sleep "$SETTLE"
    got=$(observe "$obs")
    label="$path = $val"
    if [ "$got" = "$exp" ]; then
        PASS=$((PASS + 1)); printf "  %-46s ${G}ok${N}   %s\n" "$label" "$desc"
    else
        FAIL=$((FAIL + 1)); printf "  %-46s ${R}FAIL${N} %s: expected %s, observed %s\n" \
            "$label" "$obs" "$exp" "$got"
    fi
done < <(printf '%s\n' "$CASES")

cp "$backup" "$CFG"
sleep "$SETTLE"
echo
printf "%s\n" "----"
if [ "$FAIL" -eq 0 ]; then printf "${G}PASS${N} %d setting(s) observably took effect\n" "$PASS"; exit 0
else printf "${R}FAIL${N} %d setting(s) changed nothing observable, %d ok\n" "$FAIL" "$PASS"; exit 1; fi
