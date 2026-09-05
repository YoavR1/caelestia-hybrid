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
bar|position|"top"|[10, 60, 10, 10]|the bar reserves the top edge
bar|position|"bottom"|[10, 10, 10, 60]|the bar reserves the bottom edge
bar|position|"left"|[60, 10, 10, 10]|the bar reserves the left edge
bar|position|"right"|[10, 10, 60, 10]|the bar reserves the right edge
bar|persistent|false|[10, 10, 10, 10]|a non-persistent bar reserves nothing
border|thickness|24|[24, 88, 24, 24]|border thickness scales every edge
EOP
)

if [ "${1:-}" = "--list" ]; then
    printf '%s\n' "$CASES" | while IFS='|' read -r node key val exp desc; do
        [ -z "$node" ] && continue
        printf "  %-8s %-12s = %-10s -> %-18s  %s\n" "$node" "$key" "$val" "$exp" "$desc"
    done
    exit 0
fi

command -v hyprctl >/dev/null || { echo "hyprctl not found" >&2; exit 2; }
[ -f "$CFG" ] || { echo "no config at $CFG" >&2; exit 2; }
pgrep -x qs >/dev/null || { echo "no shell running" >&2; exit 2; }

reserved() {
    hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["reserved"])'
}

set_key() {
    python3 - "$CFG" "$1" "$2" "$3" <<'PY'
import json, sys
path, node, key, raw = sys.argv[1:5]
try:
    val = json.loads(raw)
except json.JSONDecodeError:
    val = raw
d = json.load(open(path))
d.setdefault(node, {})[key] = val
json.dump(d, open(path, "w"), indent=2)
PY
}

backup=$(mktemp)
cp "$CFG" "$backup"
# Restore on any exit, including an interrupt: leaving someone's bar somewhere they
# did not put it is not an acceptable failure mode for a test.
trap 'cp "$backup" "$CFG"; rm -f "$backup"; sleep 1' EXIT

baseline() {
    set_key bar persistent true
    set_key bar position '"top"'
    set_key border thickness 10
    sleep "$SETTLE"
}

echo
echo "hw-effects: writing settings and observing the result"
baseline
start=$(reserved)
if [ "$start" != "[10, 10, 10, 10]" ] && [ "$start" != "[10, 60, 10, 10]" ]; then
    echo "  ${Y}note${N} baseline reserved is $start, not the expected [10, 60, 10, 10]"
fi
echo

while IFS='|' read -r node key val exp desc; do
    [ -z "$node" ] && continue
    baseline
    set_key "$node" "$key" "$val"
    sleep "$SETTLE"
    got=$(reserved)
    label="$node.$key = $val"
    if [ "$got" = "$exp" ]; then
        PASS=$((PASS + 1)); printf "  %-28s ${G}ok${N}   %s\n" "$label" "$desc"
    else
        FAIL=$((FAIL + 1)); printf "  %-28s ${R}FAIL${N} expected %s, observed %s\n" "$label" "$exp" "$got"
    fi
done < <(printf '%s\n' "$CASES")

cp "$backup" "$CFG"
sleep "$SETTLE"
echo
printf "%s\n" "----"
if [ "$FAIL" -eq 0 ]; then printf "${G}PASS${N} %d setting(s) observably took effect\n" "$PASS"; exit 0
else printf "${R}FAIL${N} %d setting(s) changed nothing observable, %d ok\n" "$FAIL" "$PASS"; exit 1; fi
