#!/usr/bin/env bash
# Run every gate CI runs, in the cheap-first order, and say GREEN or RED once at the end.
#
#   ./hybrid/tools/verify.sh              # everything
#   ./hybrid/tools/verify.sh --quick      # skip the two -Werror builds and the smoke matrix
#   ./hybrid/tools/verify.sh --no-smoke   # everything except the compositor runs
#
# Env:
#   BUILD_DIR   default ./build       the normal build, and what the smoke matrix boots
#   WORK_DIR    default ./.verify     scratch build dirs for the compiler-specific legs
#
# This exists because the steps live in four workflows and a skill, and assembling them by
# hand is how two of them went unrun for a whole phase (T19). Three details it encodes:
#
#   * A build directory belongs to one compiler. Reconfiguring an existing one for another
#     keeps the first one's interface flags -- a clang configure over a gcc cache produced
#     `unknown argument: -mno-direct-extern-access` on 126 of 127 files.
#   * clang-tidy's build directory must be named exactly "build" (nested is fine). TWO
#     filters act on it and they want different things. .clang-tidy excludes generated
#     *headers* with ExcludeHeaderFilterRegex 'build/.*', which is unanchored, so a
#     "tidy-build" satisfies it. CI's -source-filter '^(?!.*/build/)' excludes generated
#     *sources* and needs a literal "/build/" path component, which "tidy-build" does not
#     contain. Satisfy only the first and Qt's own generated .cpp -- mocs_compilation,
#     qmltyperegistrations, qrc_qmake_* -- are linted as project sources: measured, 316
#     diagnostics from "tidy-build" and 0 from "build", same tree, same command.
#   * Every numeric gate goes through `count`, which sets the failure flag. A gate that
#     prints a number without failing on it is not a gate (T23).

set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

BUILD_DIR=${BUILD_DIR:-$ROOT/build}
WORK_DIR=${WORK_DIR:-$ROOT/.verify}
QUICK=0
SMOKE=1

for arg in "$@"; do
    case $arg in
        --quick)    QUICK=1; SMOKE=0 ;;
        --no-smoke) SMOKE=0 ;;
        -h|--help)  sed -n '2,26p' "$0"; exit 0 ;;
        *)          echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

fail=0
step() { printf '\n\033[1m===== %s =====\033[0m\n' "$1"; }
count() { echo "$2: $1"; [ "$1" -eq 0 ] || fail=1; }

# Passed empty exactly as build.yml does, so the gate never depends on the network or on how
# the tree is tagged. CMake derives both from the local checkout otherwise (T34).
cfg=(-G Ninja -DVERSION= -DGIT_REVISION=)

step "build"
cmake -B "$BUILD_DIR" "${cfg[@]}" -DCMAKE_EXPORT_COMPILE_COMMANDS=ON >/dev/null || fail=1
cmake --build "$BUILD_DIR" 2>&1 | tail -1

step "qmlformat"
n=0
for f in $(git ls-files '*.qml'); do
    /usr/lib/qt6/bin/qmlformat "$f" | diff -q "$f" - >/dev/null 2>&1 || { echo "  DRIFT $f"; n=$((n + 1)); }
done
count "$n" drift

step "clang-format"
count "$(git ls-files '*.cpp' '*.hpp' | xargs clang-format --dry-run --Werror 2>&1 | grep -c 'error:')" drift

step "conventions"
conv=$(python3 scripts/qml-lint-conventions.py 2>&1)
echo "$conv" | tail -1
echo "$conv" | grep -q 'No violations found' || fail=1

step "qmllint self-test"
./hybrid/tools/qml-lint.sh --self-test | tail -1; ./hybrid/tools/qml-lint.sh --self-test >/dev/null || fail=1

step "qmllint"
./hybrid/tools/qml-lint.sh >/dev/null 2>&1 && echo clean || { echo FAILED; fail=1; }

# The four checks below cover bug classes every other gate is blind to. Each needs no build.
step "dead-signals self-test"; ./hybrid/tools/dead-signals.py --self-test | tail -1; ./hybrid/tools/dead-signals.py --self-test >/dev/null || fail=1
step "dead signals";  ./hybrid/tools/dead-signals.py      | tail -1; ./hybrid/tools/dead-signals.py      >/dev/null || fail=1
step "dead-qml self-test"; ./hybrid/tools/dead-qml.py --self-test | tail -1; ./hybrid/tools/dead-qml.py --self-test >/dev/null || fail=1
step "dead qml";      ./hybrid/tools/dead-qml.py          | tail -1; ./hybrid/tools/dead-qml.py          >/dev/null || fail=1
step "shell-safety self-test"; ./hybrid/tools/shell-safety.py --self-test | tail -1; ./hybrid/tools/shell-safety.py --self-test >/dev/null || fail=1
step "shell safety";  ./hybrid/tools/shell-safety.py      | tail -1; ./hybrid/tools/shell-safety.py      >/dev/null || fail=1
step "dead-config self-test"; ./hybrid/tools/dead-config.py --self-test | tail -1; ./hybrid/tools/dead-config.py --self-test >/dev/null || fail=1
step "dead config";   ./hybrid/tools/dead-config.py       | tail -1; ./hybrid/tools/dead-config.py       >/dev/null || fail=1
step "singleton self-test"
./hybrid/tools/singleton-members.py --self-test | tail -1; ./hybrid/tools/singleton-members.py --self-test >/dev/null || fail=1
step "singletons";    ./hybrid/tools/singleton-members.py | tail -1; ./hybrid/tools/singleton-members.py >/dev/null || fail=1
step "index modes";   ./hybrid/tools/check-index-modes.sh || fail=1

step "plugin tests"
./hybrid/tools/plugin-test.sh || fail=1

if [ "$QUICK" = 0 ]; then
    step "clang-tidy"
    cmake -B "$WORK_DIR/build" "${cfg[@]}" -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON >/dev/null || fail=1
    cmake --build "$WORK_DIR/build" >/dev/null 2>&1     # generates the .pb.h files
    count "$(run-clang-tidy -p "$WORK_DIR/build" -quiet -j "$(nproc)" -warnings-as-errors='*' \
        -source-filter='^(?!.*/build/).*\.cpp$' 2>&1 | grep -cE 'error:|warning:')" diagnostics

    # Not redundant with the build above, and not with each other: every clazy finding is
    # invisible to gcc, and clang stops at -ferror-limit=20, so re-run until a *clean* run.
    for cc in g++ clazy; do
        step "$cc -Werror"
        cmake -B "$WORK_DIR/$cc-build" "${cfg[@]}" -DCMAKE_CXX_COMPILER="$cc" \
            -DCMAKE_CXX_FLAGS=-Werror >/dev/null || fail=1
        count "$(cmake --build "$WORK_DIR/$cc-build" -- -k 0 2>&1 | grep -cE 'error:|warning:')" diagnostics
    done
fi

if [ "$SMOKE" = 1 ]; then
    step "smoke self-test"
    ./hybrid/tools/smoke-matrix.sh --self-test 2>&1 | tail -1
    [ "${PIPESTATUS[0]}" -eq 0 ] || fail=1

    step "smoke matrix"
    # Keep the whole run. `tail -3` showed only the verdict, so a failure said
    # "1/14 run(s) failed" and nothing about which one -- twice in one day, and
    # both times the answer needed a separate re-run to recover.
    smoke_log=$(mktemp)
    ./hybrid/tools/smoke-matrix.sh --hypr both > "$smoke_log" 2>&1
    smoke_rc=$?
    if [ "$smoke_rc" -eq 0 ]; then
        tail -3 "$smoke_log"
        rm -f "$smoke_log"
    else
        # Everything, not a filtered view of it. The harness already caps what it
        # prints per run, and the useful part of an IPC failure is the error text,
        # which matches none of the obvious patterns -- a grep here would rebuild
        # the same blind spot `tail -3` had.
        cat "$smoke_log"
        echo "  (full smoke output kept at $smoke_log)"
        fail=1
    fi
fi

if [ "$fail" -eq 0 ]; then
    printf '\n\033[1;32m===== GREEN =====\033[0m\n'
else
    printf '\n\033[1;31m===== RED =====\033[0m\n'
fi
exit $fail
