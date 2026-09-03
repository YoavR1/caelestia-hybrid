#!/usr/bin/env bash
# Build and run the C++ plugin tests in hybrid/tools/tests/.
#
#   ./hybrid/tools/plugin-test.sh              # all of them
#   ./hybrid/tools/plugin-test.sh ukey2        # just the ones whose name matches
#   BUILD_DIR=/path/to/build ./hybrid/tools/plugin-test.sh
#
# The plugin has no test target -- upstream ships none, and adding one would put
# project-owned code in an upstream-shaped path (rule 5). These live in hybrid/ instead and
# link the tree's own sources directly, which is enough for anything that is a plain class.
#
# Three build details this exists to get right:
#
#   * Arch's Qt6 is built with -mno-direct-extern-access and anything linking it must be
#     too, or the link fails on "copy relocation against non-copyable protected symbol".
#   * moc output is taken from BUILD_DIR's autogen directory rather than regenerated, so a
#     test always matches the headers the real build saw. Its hashed directory name is
#     found by locating a known moc file, never hardcoded.
#   * Generated protobuf sources and the tests themselves compile with -w for the same
#     reason the real build does it: protoc's output is not ours to lint.

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

BUILD_DIR=${BUILD_DIR:-$ROOT/build}
SVC=$ROOT/plugin/src/Caelestia/Services
GEN=$BUILD_DIR/plugin/src/Caelestia/Services
FILTER=${1:-}

if [ ! -f "$GEN/ukey.pb.cc" ]; then
    # VERSION and GIT_REVISION are parsed from *remote* tags, and this repo has no remote
    # yet, so a bare configure is a FATAL_ERROR. Pass them empty, exactly as build.yml does.
    echo "building $BUILD_DIR first" >&2
    cmake -B "$BUILD_DIR" -G Ninja -DVERSION= -DGIT_REVISION= >/dev/null 2>&1 || exit 1
    cmake --build "$BUILD_DIR" --target caelestia-services >/dev/null 2>&1 || exit 1
fi

# moc output is spread over SEVERAL hashed subdirectories -- beattracker's and QuickShare's
# land in different ones -- so each file is resolved by name rather than by assuming one
# directory holds them all. Guard on the find result, not on a dirname: `dirname ""` is "."
# and "." is a directory, so a missing autogen tree would otherwise sail past the check and
# fail later at the compile with a much worse message.
AUTOGEN_ROOT=$GEN/caelestia-services_autogen
moc() {
    local f
    f=$(find "$AUTOGEN_ROOT" -name "$1" 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "no $1 under $AUTOGEN_ROOT -- build the tree first" >&2; exit 1; }
    printf '%s' "$f"
}
[ -d "$AUTOGEN_ROOT" ] || { echo "no moc output under $GEN -- build the tree first" >&2; exit 1; }
# every autogen subdirectory is an include path, since generated headers are spread too
AUTOGEN_INCLUDES=()
while IFS= read -r d; do AUTOGEN_INCLUDES+=(-I"$d"); done < <(find "$AUTOGEN_ROOT" -type d)

QTFLAGS=$(pkg-config --cflags --libs Qt6Core Qt6Qml)
COMMON=(-std=c++20 -O1 -mno-direct-extern-access -w -fPIC -I"$SVC" -I"$ROOT/plugin/src"
        "${AUTOGEN_INCLUDES[@]}")

# name : extra sources : extra pkg-config packages
TESTS=(
    "ukey2-loopback:$SVC/QuickShare/QuickShareCrypto.cpp $GEN/securemessage.pb.cc $GEN/ukey.pb.cc:protobuf libcrypto"
    "beat-signal:$SVC/beattracker.cpp $SVC/audioprovider.cpp $SVC/audiocollector.cpp $SVC/service.cpp $(moc moc_beattracker.cpp) $(moc moc_audioprovider.cpp) $(moc moc_audiocollector.cpp) $(moc moc_service.cpp):aubio libpipewire-0.3"
    # mdns-name #includes QuickShareDiscovery.cpp to reach a file-local helper, so the
    # .cpp itself must NOT also be on the command line -- only its moc output.
    "mdns-name:$(moc moc_QuickShareDiscovery.cpp):Qt6DBus Qt6Network"
    # payload-frame also #includes its subject, so QuickShareConnection.cpp is absent here
    # too. It drags in the crypto and six generated protobuf units by reference.
    "payload-frame:$SVC/QuickShare/QuickShareCrypto.cpp $(moc moc_QuickShareConnection.cpp) $GEN/device_to_device_messages.pb.cc $GEN/offline_wire_formats.pb.cc $GEN/securegcm.pb.cc $GEN/securemessage.pb.cc $GEN/ukey.pb.cc $GEN/wire_format.pb.cc:protobuf libcrypto Qt6Network"
)

rc=0
ran=0
for spec in "${TESTS[@]}"; do
    name=${spec%%:*}
    rest=${spec#*:}
    srcs=${rest%%:*}
    pkgs=${rest#*:}

    [ -n "$FILTER" ] && [[ $name != *"$FILTER"* ]] && continue
    ran=$((ran + 1))

    out=$BUILD_DIR/hybrid-test-$name
    # shellcheck disable=SC2086,SC2046  # srcs and pkg-config output are flag lists
    if ! g++ "${COMMON[@]}" -o "$out" "$ROOT/hybrid/tools/tests/$name.cpp" $srcs \
        -I"$GEN" $QTFLAGS $(pkg-config --cflags --libs $pkgs); then
        echo "  $name: BUILD FAILED"
        rc=1
        continue
    fi

    printf '  %-16s ' "$name"
    if QT_QPA_PLATFORM=offscreen "$out"; then :; else rc=1; fi
done

if [ "$ran" -eq 0 ]; then
    echo "no test matched '$FILTER'" >&2
    exit 1
fi
exit $rc
