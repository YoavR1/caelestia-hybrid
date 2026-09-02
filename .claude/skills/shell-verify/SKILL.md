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
find . -path ./build -prune -o -name '*.qml' -print | xargs /usr/lib/qt6/bin/qmlformat --check
find plugin extras -name '*.cpp' -o -name '*.hpp' | xargs clang-format --dry-run --Werror
python3 scripts/qml-lint-conventions.py        # has a --fix mode; see T9

# 3. QML lint — any output at all is a failure
touch .qmlls.ini
_t=$(mktemp -d)                       # isolate: this still writes to state/cache
XDG_STATE_HOME="$_t/state" XDG_CACHE_HOME="$_t/cache" \
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/build/qml:$QML2_IMPORT_PATH" timeout 3 qs -p .
rm -rf "$_t"
#   ^ this is TOOLING GENERATION, not a test. It writes .qmlls.ini and is expected to
#     fail on PanelWindow. Never read its exit code. Isolate XDG_STATE_HOME/XDG_CACHE_HOME
#     anyway — even a failed boot touches ~/.local/state/caelestia/apps.sqlite.
/usr/lib/qt6/bin/qmllint --import disable -I <buildDir> -I <importPaths from .qmlls.ini> <files>

# 4. Preset smoke matrix — the project's real gate
./hybrid/tools/smoke-matrix.sh
```

Steps 2 and 3 mirror `.github/workflows/check-format.yml` and `lint.yml`. If those workflows
have drifted from what is written here, **the workflow is the source of truth** — read it and
update this skill.

## Reading smoke-matrix results

`smoke-matrix.sh` spawns a **nested Hyprland**, then boots the shell under each preset against
it in an isolated `XDG_CONFIG_HOME`, and kills it after a window.

It cannot use `QT_QPA_PLATFORM=offscreen`: Quickshell's `PanelWindow` is a wlr-layer-shell
surface, and with no Wayland backend it is unavailable — which poisons the entire singleton
graph with `No PanelWindow backend loaded` (trap T12). The runner refuses to use your live
session socket, so it can never draw over your desktop.

| Result | Meaning |
|---|---|
| `ok` | Booted and stayed up for the whole window with no QML diagnostics. |
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
