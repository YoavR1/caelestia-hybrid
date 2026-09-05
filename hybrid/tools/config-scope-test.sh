#!/usr/bin/env bash
# Assert the config resolver's scope semantics against the real plugin.
#
# The settings UI writes every value through `GlobalConfig.forScreen(targetScreen)`,
# and passes "" for its "Global" scope. When an empty name resolved to a layer
# rather than the root, all 372 keys silently wrote to a file nothing reads (T62).
# That is a property of the resolver, so one test covers every key at once.
#
# Runs against an isolated XDG_CONFIG_HOME: a test that mutates the developer's own
# settings is not one anyone will run twice.
set -uo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
QS=${QS:-qs}
BUILD_DIR=${BUILD_DIR:-$ROOT/build}

command -v "$QS" >/dev/null || { echo "qs not found on PATH" >&2; exit 2; }
[ -d "$BUILD_DIR/qml" ] || { echo "$BUILD_DIR/qml missing -- build first" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
result=$tmp/result.txt

# A fresh config dir, so the shell starts from compiled defaults and writes nowhere real.
mkdir -p "$tmp/config/caelestia"

out=$tmp/run.log
QT_QPA_PLATFORM=offscreen \
XDG_CONFIG_HOME="$tmp/config" \
XDG_STATE_HOME="$tmp/state" \
XDG_CACHE_HOME="$tmp/cache" \
CONFIG_SCOPE_RESULT="$result" \
QML2_IMPORT_PATH="$BUILD_DIR/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}" \
CAELESTIA_LIB_DIR="$BUILD_DIR/lib" \
    timeout 90 "$QS" -p "$ROOT/hybrid/tools/tests/config-scope" >"$out" 2>&1
rc=$?

if [ ! -s "$result" ]; then
    # No verdict written at all: the shell failed to load, or died before finishing.
    echo "  config-scope: the test wrote no result (qs rc=$rc)"
    grep -aE 'ERROR|error:|Failed' "$out" | head -6 | sed 's/^/      /'
    exit 1
fi

cat "$result" | sed 's/^/  /'
grep -q '^PASS' "$result"
