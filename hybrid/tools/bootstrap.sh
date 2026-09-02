#!/usr/bin/env bash
# Phase 0 — turn this directory into the Caelestia Hybrid repository.
#
# Idempotent: safe to re-run. Never deletes anything, never touches a running shell.
#
#   ./hybrid/tools/bootstrap.sh
#
# Env:
#   CAELESTIA_REFS   where to put read-only upstream worktrees (default ../caelestia-refs)

set -euo pipefail

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m warn\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m fail\033[0m %s\n' "$*" >&2; exit 1; }

cd "$(dirname "$0")/../.."
ROOT=$PWD
REFS=${CAELESTIA_REFS:-$ROOT/../caelestia-refs}

UPSTREAM_CAELESTIA=https://github.com/caelestia-dots/shell
UPSTREAM_OP=https://github.com/OVERxPOWERED/op-caelestia-shell
UPSTREAM_MIDNIGHT=https://github.com/dim-ghub/midnight-shell

command -v git >/dev/null || die "git not found"

# ---------------------------------------------------------------- repo + remotes

if [ ! -d .git ]; then
    say "git init"
    git init -q
fi

add_remote() {
    local name=$1 url=$2
    if git remote get-url "$name" >/dev/null 2>&1; then
        [ "$(git remote get-url "$name")" = "$url" ] || warn "remote '$name' points elsewhere; leaving as-is"
    else
        say "remote add $name"
        git remote add "$name" "$url"
    fi
}

add_remote caelestia "$UPSTREAM_CAELESTIA"
add_remote op        "$UPSTREAM_OP"
add_remote midnight  "$UPSTREAM_MIDNIGHT"

say "fetching all upstreams (this takes a minute)"
git fetch --all --tags --quiet

# ------------------------------------------------------------------- git config

# The single highest-value setting for this project: remember conflict resolutions
# across the repeated upstream merges. See architecture.md D9.
say "enabling git rerere"
git config rerere.enabled true
git config rerere.autoupdate true

# Upstream C++/QML is LF; we may author on Windows.
git config core.autocrlf false

# ------------------------------------------------------------------ main branch

if git rev-parse --verify -q main >/dev/null; then
    say "branch 'main' already exists — leaving it alone"
else
    say "creating 'main' from midnight/main (baseline, decision D1)"

    # Refuse to clobber untracked scaffolding. MiDnight has no CLAUDE.md/.claude/hybrid,
    # so this should never trigger — but check rather than trust.
    collisions=$(git ls-tree -r --name-only midnight/main \
        | while read -r f; do [ -e "$ROOT/$f" ] && echo "$f"; done || true)
    [ -z "$collisions" ] || die "would overwrite existing files:
$collisions
Move them aside and re-run."

    git checkout -q -b main midnight/main
fi

# ------------------------------------------------------- reference checkouts

say "reference worktrees -> $REFS"
mkdir -p "$REFS"
for pair in "upstream:caelestia/main" "op:op/main" "midnight:midnight/main"; do
    name=${pair%%:*}
    ref=${pair##*:}
    if [ -d "$REFS/$name/.git" ] || [ -f "$REFS/$name/.git" ]; then
        git -C "$REFS/$name" checkout -q --detach "$ref" 2>/dev/null \
            && say "  refreshed $name -> $ref" \
            || warn "  could not refresh $name"
    else
        git worktree add -q --detach "$REFS/$name" "$ref" && say "  created $name -> $ref"
    fi
done

# -------------------------------------------------------------------- CI (T9)

say "checking CI state"
disabled=$(ls .github/workflows/*.disabled 2>/dev/null || true)
if [ -n "$disabled" ]; then
    warn "MiDnight ships CI disabled (trap T9). Not all of these should come back:"
    for f in $disabled; do
        base=$(basename "$f" .disabled)
        case $base in
            check-format.yml|lint.yml)
                printf '        %-28s re-enable — quality gate\n' "$base" ;;
            release.yml)
                printf '        %-28s leave off until there is a release process (needs contents:write)\n' "$base" ;;
            update-flake-inputs.yml)
                printf '        %-28s leave off — scheduled bot that commits to the repo\n' "$base" ;;
            update-image.yml)
                printf '        %-28s leave off permanently — publishes an image we consume from upstream\n' "$base" ;;
            *)
                printf '        %-28s review before enabling\n' "$base" ;;
        esac
    done
    warn "Re-enable the two quality gates, then repoint their container image:"
    warn "  ghcr.io/\${{ github.repository_owner }}/  ->  ghcr.io/caelestia-dots/"
    warn "A fork does not publish shell-arch-env, so the templated owner resolves to nothing."
fi

# ------------------------------------------------------------------- gitignore

for entry in '.smoke-logs/' '.qmlls.ini'; do
    if [ -f .gitignore ] && grep -qxF "$entry" .gitignore; then
        continue
    fi
    say "gitignore += $entry"
    printf '%s\n' "$entry" >> .gitignore
done

# ------------------------------------------------------------------------ done

cat <<'NEXT'

Bootstrap complete.

  Remotes    origin(none yet) caelestia op midnight
  Branch     main  <- midnight/main
  rerere     enabled
  Refs       see $CAELESTIA_REFS

Next (Phase 0):
  1. git remote add origin <your fork url>
  2. Re-enable CI workflows and repoint the container image  (trap T9)
  3. Commit the hybrid/ + .claude/ + CLAUDE.md scaffold as the first hybrid commit
  4. Run  hybrid/tools/upstream-status.sh  to see current drift
  5. Build, then  hybrid/tools/smoke-matrix.sh  to establish the noise baseline

Never run OP's install.sh here — it does killall -9 quickshell and rm -rf. Use dev-shell.sh.
NEXT
