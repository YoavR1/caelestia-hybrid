---
name: shell-verify
description: >-
  The verification gate for Caelestia Hybrid — build, qmlformat, clang-format, qmllint, and the
  nested-compositor preset smoke matrix. Use before claiming any change is done, after importing
  a feature, after resolving an upstream merge, and whenever asked whether something builds,
  passes, or works. Also use when a QML error, binding loop, or startup crash needs reproducing,
  or when qmllint or qmlformat behave oddly on this machine.
---

# Verification gate

Nothing is done until this passes. Run the whole gate, in order, and report actual output —
never "should work".

**This only runs on Linux.** Quickshell needs Qt6 and Wayland. If the working machine is not
Linux, say so plainly and stop rather than guessing at results.

## Two environment facts that will bite you

**1. `/usr/bin/qmllint` is not Qt's linter.** On Arch/CachyOS it is an unrelated tool reporting
`qmllint 1.0`, and it rejects `--import`. Qt's lives at `/usr/lib/qt6/bin/`. Same for
`qmlformat`. This is why upstream CI hardcodes the full path — always do the same.

**2. The Bash tool runs `zsh` here.** `mapfile`, `read -ra` and other bashisms fail. Wrap
multi-line shell in `bash -c '...'`. The project's own scripts are fine — they have
`#!/usr/bin/env bash` shebangs.

## The gate

```bash
# 1. Build (also generates build/qml that the linter and smoke runner need)
cmake -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build

# 2. Format — zero tolerance, same as upstream CI
for f in **/*.qml; /usr/lib/qt6/bin/qmlformat $f | diff -u $f - || exit 1; end
git ls-files '*.cpp' '*.hpp' | xargs clang-format --dry-run --Werror   # wider than CI, on purpose
python3 scripts/qml-lint-conventions.py        # --fix handles all but section-order
./hybrid/tools/qml-section-order.py            # the missing section-order fixer

# 3. QML lint — any output at all is a failure
./hybrid/tools/qml-lint.sh                     # or --summary for category counts

# 4. Two cheap repo-hygiene checks, both invisible to every other gate
./hybrid/tools/dead-signals.py       # signals declared but never emitted (T21)
./hybrid/tools/check-index-modes.sh  # scripts committed non-executable (T22)

# 5. C++ lint — needs its OWN clang configure. Arch's Qt6 hands gcc
#    -mno-direct-extern-access, which clang-tidy rejects on every file (T19).
#    The directory name must END in "build": .clang-tidy excludes generated headers with
#    ExcludeHeaderFilterRegex 'build/.*', so "tidy-build" works and "build-tidy" does not.
cmake -B tidy-build -G Ninja -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
  -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON && cmake --build tidy-build   # generates the .pb.h
run-clang-tidy -p tidy-build -quiet -j (nproc) -warnings-as-errors='*' \
  -source-filter='^(?!.*/build/).*\.cpp$'

# 6. Both -Werror build legs. NOT redundant with step 1, and not with each other:
#    every clazy finding is invisible to gcc. Use a fresh dir per compiler (T19).
cmake -B /tmp/w-gcc   -G Ninja -DCMAKE_CXX_COMPILER=g++   -DCMAKE_CXX_FLAGS=-Werror && cmake --build /tmp/w-gcc
cmake -B /tmp/w-clazy -G Ninja -DCMAKE_CXX_COMPILER=clazy -DCMAKE_CXX_FLAGS=-Werror && cmake --build /tmp/w-clazy

# 7. The plugin's C++ tests (QuickShare handshake, BeatTracker signal)
./hybrid/tools/plugin-test.sh

# 8. Preset smoke matrix — the project's real gate
./hybrid/tools/smoke-matrix.sh              # nested Hyprland, lua config
./hybrid/tools/smoke-matrix.sh --hypr both  # both Hyprland config formats
```

Steps 2–6 mirror `.github/workflows/check-format.yml`, `lint.yml` and `build.yml`. If those
workflows have drifted from what is written here, **the workflow is the source of truth** —
read it and update this skill. The one deliberate difference: CI's format check globs
`plugin extras`, and there is now C++ under `hybrid/tools/tests/` too, so this checks every
tracked source instead.

**Step 6 is the one that gets skipped.** `build.yml` has passed `-DCMAKE_CXX_FLAGS=-Werror`
on both its legs since before this fork existed, and nothing local ever passed it, so the two
legs sat red through a phase that reported CI green. Re-run each until a *clean* run, not a
*short* one — clang stops at `-ferror-limit=20`, so a shrinking count can still be a truncated
one. See trap T19.

**`qmlformat` has no `--check`.** It exits 0 and prints `Unknown option 'check'`, so a check
written that way passes while testing nothing. Upstream compares against `diff` instead, which
is what the loop above does — `qml-lint.sh` and the two fixers already do the right thing.

`qml-lint.sh` wraps the fiddly part of step 3: the `-I` paths come from `.qmlls.ini`, which
`qs` writes **only if the file already exists** (hence upstream's `touch`) and then replaces
with a symlink into that run's VFS, which goes dangling later. The boot that generates it is
expected to fail on PanelWindow — its exit code is meaningless — and it is run with
`XDG_STATE_HOME`/`XDG_CACHE_HOME` isolated, because even a failed boot writes to
`~/.local/state/caelestia/apps.sqlite`.

## Reading smoke-matrix results

`smoke-matrix.sh` spawns a **nested Hyprland**, then boots the shell under each preset against
it in an isolated `XDG_CONFIG_HOME`, and kills it after a window.

Two compositor backends:

| | when | covers |
|---|---|---|
| Hyprland (default) | a display exists to nest in | everything, including Hyprland IPC and the `usingLua` lua/conf axis (`--hypr both`) |
| headless sway (`--compositor sway`) | no display — CI, a tty, a container | load errors, unresolved types, binding errors. `Hypr.*` is inert |

It picks automatically and says which it chose. Hyprland **cannot** run headless — see T12 — so
CI uses sway, with `hybrid/tools/smoke-ignore-headless.txt` layered on top of the main ignore
list for that run only.

It cannot use `QT_QPA_PLATFORM=offscreen`: Quickshell's `PanelWindow` is a wlr-layer-shell
surface, and with no Wayland backend it is unavailable — which poisons the entire singleton
graph with `No PanelWindow backend loaded` (trap T12). The runner refuses to use your live
session socket, so it can never draw over your desktop.

Each run boots the shell **and then drives it**: every drawer opened and closed over IPC,
the launcher sent to emoji and clipboard mode, a toast raised, Nexus opened. Booting alone
misses most of the interesting bugs — the first interaction run found a `ReferenceError` in
the emoji list and a null `targetConfig` on every settings page, neither reachable at boot.
`--no-interact` drops back to boot-only, which is only useful while bisecting a boot
failure.

| Result | Meaning |
|---|---|
| `ok` | Came up, survived being driven, and emitted no QML diagnostics. |
| `FAIL (exited early, rc=N)` | The shell died. Read the printed head of the log — usually a load error. |
| `FAIL` + diagnostic lines | It stayed up but emitted QML errors or warnings. |

Useful flags: `--keep-logs` (leaves logs in `.smoke-logs/`), `--timeout N`, and a preset name
to run just one.

## The ignore file

`hybrid/tools/smoke-ignore.txt` suppresses environment noise — a headless container has no
Hyprland socket, no PipeWire and no session bus, so some diagnostics are not bugs.

- On a fresh target, populate it **once** with `./hybrid/tools/smoke-matrix.sh --baseline`.
- Then **read every appended line** and delete the ones that are genuine bugs. It is reviewed
  code, not a dumping ground.
- Never add `TypeError`, `is not defined`, `Unable to assign`, or anything naming one of our own
  QML files. Those are bugs — fix them.

Adding an ignore entry to make a failure disappear is the single easiest way to make this
project's quality invisible. Don't.

## Extending coverage

Arbitrary feature/variant combinations are covered by adding presets, not by writing a test
matrix in code (architecture.md §5). Each boot costs seconds, so add hostile ones:

- everything on, everything off
- every `variants` value flipped from the recommended default
- one preset per newly imported feature, with only that feature on

Drop a `*.json` in `hybrid/presets/` and the runner picks it up.

## When something fails

1. Reproduce it in isolation: `./hybrid/tools/smoke-matrix.sh <preset> --keep-logs`
2. Read `.smoke-logs/<preset>.log` — the first error usually causes the rest.
3. For interactive debugging on a real session, use `./hybrid/tools/dev-shell.sh`, which is
   config-isolated (T4) and never touches the installed shell.
4. **Never** `killall quickshell` to recover. Ctrl-C the dev instance.
