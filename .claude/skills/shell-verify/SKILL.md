---
name: shell-verify
description: >-
  The verification gate for Caelestia Hybrid — build, clang-format, qmllint, and the headless
  offscreen preset smoke matrix. Use before claiming any change is done, after importing a
  feature, after resolving an upstream merge, and whenever asked whether something builds,
  passes, or works. Also use when a QML error, binding loop, or startup crash needs
  reproducing headlessly.
---

# Verification gate

Nothing is done until this passes. Run the whole gate, in order, and report actual output —
never "should work".

**This only runs on Linux.** Quickshell needs Qt6 and Wayland. If the working machine is not
Linux, say so plainly and stop rather than guessing at results.

## The gate

```bash
# 1. Build (also generates build/qml that the linter and smoke runner need)
cmake -B build -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build

# 2. Format — zero tolerance, same as upstream CI
find . -path ./build -prune -o -name '*.qml' -print | xargs qmlformat --check 2>&1 | tee /dev/stderr | grep -q . && echo "QML FORMAT FAIL"
find plugin/src -name '*.cpp' -o -name '*.hpp' | xargs clang-format --dry-run --Werror

# 3. QML lint — any output at all is a failure
touch .qmlls.ini
QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$PWD/build/qml:$QML2_IMPORT_PATH" timeout 2 qs -p .
qmllint --import disable -I build/qml $(find . -path ./build -prune -o -name '*.qml' -print)

# 4. Headless preset smoke matrix — the project's real gate
./hybrid/tools/smoke-matrix.sh
```

Steps 2 and 3 mirror `.github/workflows/check-format.yml` and `lint.yml`. If those workflows
have drifted from what is written here, **the workflow is the source of truth** — read it and
update this skill.

## Reading smoke-matrix results

`smoke-matrix.sh` boots the shell under each preset in an isolated `XDG_CONFIG_HOME` with
`QT_QPA_PLATFORM=offscreen`, and kills it after a window.

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
