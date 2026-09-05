#!/usr/bin/env bash
# Exercise the whole shell against a live session, and use its own log as the oracle.
#
# `hw-verify.sh` answers "can the user reach the panels". This answers the broader
# question: does every IPC entry point, every Nexus page and every feature flag do
# something without the shell complaining. The checklist is derived from the source
# rather than remembered -- `--list` prints it -- so a new IPC handler shows up here
# by existing, not by someone thinking to add it.
#
# The oracle is `qs log`. Anything the shell prints at ERROR level while a probe runs
# is that probe's failure. Warnings are reported but do not fail, because this tree
# starts with several that are about the machine rather than the code (no bluez, no
# ~/.face, no ollama), and T45 is the standing reminder that filtering a gate's output
# until it passes is how you get a gate that cannot fail.
#
#   ./hybrid/tools/hw-audit.sh                 # safe probes only
#   ./hybrid/tools/hw-audit.sh --disruptive    # also the ones that change visible state
#   ./hybrid/tools/hw-audit.sh --list          # print the checklist and exit
set -uo pipefail

export LANG=${LANG:-C.UTF-8}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
: "${HYPRLAND_INSTANCE_SIGNATURE:=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QS_SEL=(-c caelestia)
[ -n "${HW_AUDIT_PATH:-}" ] && QS_SEL=(-p "$HW_AUDIT_PATH")

DISRUPTIVE=0
LIST_ONLY=0
for a in "$@"; do
    case "$a" in
        --disruptive) DISRUPTIVE=1 ;;
        --list) LIST_ONLY=1 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown flag: $a" >&2; exit 2 ;;
    esac
done

G=$'\033[1;32m'; R=$'\033[1;31m'; Y=$'\033[0;33m'; B=$'\033[1m'; N=$'\033[0m'
PASS=0; FAIL=0; SKIP=0; WARNED=0

ipc()  { timeout 15 qs "${QS_SEL[@]}" ipc call "$@" 2>&1; }
logn() { qs "${QS_SEL[@]}" log 2>/dev/null | wc -l; }
logtail() { qs "${QS_SEL[@]}" log 2>/dev/null | tail -n "$1"; }

ok()   { PASS=$((PASS+1)); printf "  %-34s ${G}ok${N} %s\n" "$1" "${2:-}"; }
bad()  { FAIL=$((FAIL+1)); printf "  %-34s ${R}FAIL${N} %s\n" "$1" "${2:-}"; }
skip() { SKIP=$((SKIP+1)); printf "  %-34s ${Y}skip${N} %s\n" "$1" "${2:-}"; }

# --- the checklist, derived from the source ---------------------------------
# kind: read (no visible effect) | toggle (restored) | disruptive (needs --disruptive)
PROBES=$(cat <<'EOP'
read|drawers list|
read|drawers isOpen|dashboard
read|lock isLocked|
read|gameMode isEnabled|
read|idleInhibitor isEnabled|
read|notifs isDndEnabled|
read|mpris list|
read|mpris getActive|trackTitle
read|wallpaper get|
read|wallpaper list|
read|brightness get|
read|hypr listSpecialWorkspaces|
toggle|gameMode|
toggle|idleInhibitor|
toggle|notifs Dnd|
disruptive|notifs clear|
disruptive|audio cycleOutput|
disruptive|mpris playPause|
disruptive|hypr refreshDevices|
disruptive|picker open|
disruptive|picker openSearch|
disruptive|launcher openEmoji|
disruptive|launcher openClipboard|
EOP
)

if [ "$LIST_ONLY" = "1" ]; then
    echo "${B}probes${N}"
    printf '%s\n' "$PROBES" | while IFS='|' read -r kind call arg; do
        [ -z "$kind" ] && continue
        printf "  %-11s %s %s\n" "[$kind]" "$call" "$arg"
    done
    echo
    echo "${B}nexus pages${N}"
    grep -oP 'label: qsTr\("\K[^"]+' "$ROOT/modules/nexus/PageRegistry.qml" | nl -w4 -s'  '
    echo
    echo "${B}hybrid features${N}"
    grep -oP '^\s*FEATURE\(\K\w+' "$ROOT/plugin/src/Caelestia/Config/hybridconfig.hpp" | tr '\n' ' '
    echo; exit 0
fi

echo
echo "hw-audit: $(qs "${QS_SEL[@]}" ipc call drawers list 2>/dev/null | wc -l) drawers, log at $(logn) lines"
[ "$DISRUPTIVE" = "1" ] && echo "          including disruptive probes"
echo

# Anything the shell logs at ERROR while a probe runs belongs to that probe.
run_probe() {
    local label=$1; shift
    local before after new errs
    before=$(logn)
    local out; out=$("$@")
    sleep 1.2
    after=$(logn)
    new=$((after - before))
    errs=""
    if [ "$new" -gt 0 ]; then
        errs=$(logtail "$new" | grep -cE 'ERROR|error:|TypeError|ReferenceError|is not a function|Cannot read')
    fi
    if [ "${errs:-0}" -gt 0 ]; then
        bad "$label" "$errs error line(s) in the shell log"
        logtail "$new" | grep -E 'ERROR|error:|TypeError|ReferenceError' | head -2 | sed 's/^/      /'
    elif printf '%s' "$out" | grep -qiE 'no running instance|not expected|does not exist|Unknown option|Invalid property|invalid argument'; then
        bad "$label" "$(printf '%s' "$out" | head -1 | cut -c1-70)"
    else
        local detail; detail=$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-46)
        if [ "${MUST_ANSWER:-0}" = "1" ] && [ -z "$(printf '%s' "$out" | tr -d '[:space:]')" ]; then
            bad "$label" "answered nothing, and this probe has to answer something"
            return
        fi
        ok "$label" "${detail:+-> $detail}"
        if [ "$new" -gt 0 ]; then
            local w; w=$(logtail "$new" | grep -cE 'WARN')
            [ "${w:-0}" -gt 0 ] && WARNED=$((WARNED + w))
        fi
    fi
}

echo "${B}reads${N}"
# These have no meaningful empty answer: a shell that cannot say whether it is
# locked, or what the wallpaper is, has not answered the question.
MUST_ANSWER_PROBES="drawers list|lock isLocked|gameMode isEnabled|idleInhibitor isEnabled|notifs isDndEnabled|wallpaper get|brightness get"
while IFS='|' read -r _ call arg; do
    case "|$MUST_ANSWER_PROBES|" in *"|$call|"*) MUST_ANSWER=1 ;; *) MUST_ANSWER=0 ;; esac
    export MUST_ANSWER
    # shellcheck disable=SC2086
    run_probe "$call ${arg}" ipc $call $arg
done < <(printf '%s\n' "$PROBES" | grep '^read|')
MUST_ANSWER=0

echo
echo "${B}toggles (restored)${N}"
toggle_probe() {
    local target=$1 getter=$2 enable=$3 disable=$4
    local was; was=$(ipc "$target" "$getter" | tr -d '[:space:]')
    local flip; [ "$was" = "true" ] && flip=$disable || flip=$enable
    local back; [ "$was" = "true" ] && back=$enable || back=$disable
    run_probe "$target $flip" ipc "$target" "$flip"
    local now; now=$(ipc "$target" "$getter" | tr -d '[:space:]')
    if [ "$now" = "$was" ]; then
        bad "$target state changed" "still $now"
    else
        ok "$target state changed" "$was -> $now"
    fi
    ipc "$target" "$back" >/dev/null 2>&1
    sleep 0.5
    local restored; restored=$(ipc "$target" "$getter" | tr -d '[:space:]')
    [ "$restored" = "$was" ] && ok "$target restored" "$restored" || bad "$target restored" "left at $restored"
}
toggle_probe gameMode      isEnabled    enable      disable
toggle_probe idleInhibitor isEnabled    enable      disable
toggle_probe notifs        isDndEnabled enableDnd   disableDnd

echo
echo "${B}nexus pages${N}"
PAGES=$(grep -c 'label:' "$ROOT/modules/nexus/PageRegistry.qml")
before=$(logn)
opened=0
for i in $(seq 0 $((PAGES - 1))); do
    ipc nexus openPage "$i" >/dev/null 2>&1
    sleep 1.0
    opened=$((opened + 1))
done
sleep 1.5
after=$(logn); new=$((after - before))
errs=0
[ "$new" -gt 0 ] && errs=$(logtail "$new" | grep -cE 'ERROR|TypeError|ReferenceError|Cannot read')
if [ "${errs:-0}" -gt 0 ]; then
    bad "all $PAGES pages render" "$errs error line(s)"
    logtail "$new" | grep -E 'ERROR|TypeError|ReferenceError|Cannot read' | head -4 | sed 's/^/      /'
else
    ok "all $PAGES pages render" "$opened opened, 0 errors"
fi
# Close whatever those opened.
for _ in $(seq 1 "$PAGES"); do hyprctl dispatch 'hl.dsp.window.close()' >/dev/null 2>&1; sleep 0.2; done

# --- every feature flag, flipped and put back ------------------------------
# The smoke matrix boots presets, so it proves a *combination* loads. It cannot
# see a flag that breaks the shell when flipped at runtime, which is how a user
# actually meets it: the config file is watched, the flag changes live, and
# whatever the flag gates has to appear or disappear without complaint. T54 is
# the reminder that a flag can also be wired to nothing at all.
CFG=$HOME/.config/caelestia/shell.json
echo
echo "${B}feature flags (flipped live, then restored)${N}"
if [ ! -f "$CFG" ]; then
    skip "feature flags" "no $CFG to edit"
else
    CFG_BACKUP=$(mktemp)
    cp "$CFG" "$CFG_BACKUP"
    trap 'cp "$CFG_BACKUP" "$CFG" 2>/dev/null; rm -f "$CFG_BACKUP"; ipc idleInhibitor disable >/dev/null 2>&1' EXIT

    set_feature() {
        python3 - "$CFG" "$1" "$2" <<'PY'
import json, sys
path, key, val = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
d = json.load(open(path))
d.setdefault("hybrid", {}).setdefault("features", {})[key] = val
json.dump(d, open(path, "w"), indent=2)
PY
    }

    for feat in $(grep -oP '^\s*FEATURE\(\K\w+' "$ROOT/plugin/src/Caelestia/Config/hybridconfig.hpp"); do
        before=$(logn)
        set_feature "$feat" true;  sleep 1.6
        set_feature "$feat" false; sleep 1.6
        after=$(logn); new=$((after - before))
        errs=0
        [ "$new" -gt 0 ] && errs=$(logtail "$new" | grep -cE 'ERROR|TypeError|ReferenceError|Cannot read|Unknown option')
        if [ "${errs:-0}" -gt 0 ]; then
            bad "feature $feat" "$errs error line(s) on flip"
            logtail "$new" | grep -E 'ERROR|TypeError|ReferenceError|Cannot read|Unknown option' | head -2 | sed 's/^/      /'
        else
            ok "feature $feat" "on/off clean"
        fi
    done

    cp "$CFG_BACKUP" "$CFG"
    sleep 1.5
    ok "config restored" "$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(len(d.get("hybrid",{}).get("features",{})), "feature key(s)")' "$CFG" 2>/dev/null)"
fi

if [ "$DISRUPTIVE" = "1" ]; then
    echo
    echo "${B}disruptive${N}"
    while IFS='|' read -r _ call arg; do
        # shellcheck disable=SC2086
        run_probe "$call ${arg}" ipc $call $arg
        # Anything that opens a surface gets dismissed.
        hyprctl dispatch 'hl.dsp.submap("reset")' >/dev/null 2>&1
    done < <(printf '%s\n' "$PROBES" | grep '^disruptive|')
else
    echo
    n=$(printf '%s\n' "$PROBES" | grep -c '^disruptive|')
    skip "$n disruptive probe(s)" "pass --disruptive to include them"
fi

echo
printf "%s\n" "----"
[ "$WARNED" -gt 0 ] && echo "$Y$WARNED warning line(s) logged; warnings do not fail this suite$N"
if [ "$FAIL" -eq 0 ]; then printf "${G}PASS${N} %d ok, %d skipped\n" "$PASS" "$SKIP"; exit 0
else printf "${R}FAIL${N} %d failed, %d ok, %d skipped\n" "$FAIL" "$PASS" "$SKIP"; exit 1; fi
