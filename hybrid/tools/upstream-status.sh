#!/usr/bin/env bash
# Drift report across the three upstreams.
#
#   ./hybrid/tools/upstream-status.sh            # summary
#   ./hybrid/tools/upstream-status.sh --commits  # also list what we are missing
#   ./hybrid/tools/upstream-status.sh --areas    # also show which directories moved
#
# Derives everything from git. There is deliberately no upstreams.lock.json to drift
# out of sync (architecture.md, D9).

set -euo pipefail

SHOW_COMMITS=0
SHOW_AREAS=0
for a in "$@"; do
    case $a in
        --commits) SHOW_COMMITS=1 ;;
        --areas)   SHOW_AREAS=1 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) printf 'unknown option: %s\n' "$a" >&2; exit 2 ;;
    esac
done

cd "$(git rev-parse --show-toplevel)"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }

FETCHED=0
for remote in caelestia op midnight; do
    git remote get-url "$remote" >/dev/null 2>&1 || {
        printf 'remote "%s" not configured — run hybrid/tools/bootstrap.sh\n' "$remote" >&2
        exit 1
    }
done

if [ "${NO_FETCH:-0}" != "1" ]; then
    printf 'fetching...\n'
    git fetch --all --tags --quiet && FETCHED=1
fi

HEAD_SHA=$(git rev-parse --short HEAD)
bold "HEAD $HEAD_SHA  ($(git rev-parse --abbrev-ref HEAD))"
[ "$FETCHED" = 1 ] || printf '  (skipped fetch; set NO_FETCH=0 to refresh)\n'
echo

for pair in "caelestia:caelestia/main" "op:op/main" "midnight:midnight/main"; do
    name=${pair%%:*}
    ref=${pair##*:}

    git rev-parse --verify -q "$ref" >/dev/null || { printf '%-10s (no such ref)\n' "$name"; continue; }

    base=$(git merge-base HEAD "$ref" 2>/dev/null) || { printf '%-10s (no common ancestor)\n' "$name"; continue; }
    behind=$(git rev-list --count "$base..$ref")
    ahead=$(git rev-list --count "$base..HEAD")
    tip=$(git log -1 --format='%h %ad' --date=short "$ref")

    if [ "$behind" -eq 0 ]; then
        bold "$name — up to date"
    else
        bold "$name — $behind commits behind"
    fi
    printf '  tip        %s\n' "$tip"
    printf '  merge-base %s\n' "$(git log -1 --format='%h %ad %s' --date=short "$base" | cut -c1-90)"
    printf '  we are     %s commits ahead of that base\n' "$ahead"

    if [ "$behind" -gt 0 ]; then
        stat=$(git diff --shortstat "$base" "$ref" 2>/dev/null || true)
        [ -n "$stat" ] && printf '  incoming  %s\n' "$stat"

        if [ "$SHOW_AREAS" = 1 ]; then
            printf '  areas:\n'
            git diff --name-only "$base" "$ref" \
                | awk -F/ '{ if (NF>2) print $1"/"$2; else if (NF==2) print $1"/"; else print "(root)" }' \
                | sort | uniq -c | sort -rn | head -12 \
                | while read -r n d; do printf '    %5s  %s\n' "$n" "$d"; done
        fi

        if [ "$SHOW_COMMITS" = 1 ]; then
            printf '  commits:\n'
            git log --format='    %h %ad %s' --date=short "$base..$ref" | head -40
            [ "$behind" -gt 40 ] && printf '    ... and %s more\n' "$((behind - 40))"
        fi

        # Flag the changes most likely to hurt (traps T7, T10).
        risky=$(git diff --name-only "$base" "$ref" \
            | grep -E '^plugin/src/Caelestia/(Config|Settings|Plugins)/|^modules/drawers/|^services/(Audio|Colours|Wallpapers)\.qml' \
            || true)
        if [ -n "$risky" ]; then
            printf '  \033[1;33mhigh-risk paths in this range:\033[0m\n'
            printf '%s\n' "$risky" | head -12 | sed 's/^/    /'
        fi
    fi
    echo
done

cat <<'HINT'
Sync one upstream at a time, on its own branch (D9):

  git switch -c sync/caelestia/$(date +%F) && git merge caelestia/main   # true ancestor: merge
  git switch -c sync/op/$(date +%F)        && git cherry-pick -x <sha>   # OP: cherry-pick

Never rebase onto an upstream. Never combine upstreams in one sync branch.
HINT
