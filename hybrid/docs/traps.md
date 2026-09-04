# Known traps

Each entry was verified against source on 2026-09-02. Paths are upstream-relative.
When one of these bites you, extend the entry rather than burying the lesson in a commit message.

---

## T1 — `modules/drawers/Panels.qml` is a coupling graph, not a panel list

**Symptom:** you wrap a panel in a `Loader` and unrelated things break.

Panels reference each other by `id` through anchors and required properties:

```qml
osdWrapper.anchors.rightMargin: sessionWrapper.anchors.rightMargin
                                + session.width * (1 - session.offsetScale)
toasts.anchors.bottom:          sidebar.visible ? parent.bottom : utilities.top
sidebar.anchors.top:            notifications.bottom
Notifications.Wrapper { sidebarPanel: sidebar; osdPanel: osdWrapper;
                        sessionPanel: sessionWrapper; utilitiesPanel: utilities }
```

It also exposes ~11 `readonly property alias` members, and `panels.<x>` is referenced
**~107 times across 6 files** (`ContentWindow.qml`, `Interactions.qml`, `Regions.qml`,
`launcher/WallpaperList.qml`, `launcher/Wrapper.qml`, `nexus/PageCompRegistry.qml`).

**Why a Loader hurts here**

- `readonly property alias osd: osd` **cannot alias into a Loader**. Aliases need a compile-time
  target; `loader.item` is `null` until loaded. Converting to `property Item` means auditing every
  one of those call sites for null-safety.
- `Regions.qml` derives the Wayland input region from panel geometry. A null panel during load is a
  frame of wrong click-through.

**Rule:** Loader-host only weakly-referenced, self-contained modules. OP's `modules/dock/` has its
own `Wrapper`/window and is a good candidate. Inside the Panels graph, merge implementations and
switch behaviour with config properties instead.

---

## T2 — The bar has a 10-member implicit contract

`modules/drawers/Interactions.qml` (313 lines) is a global hover/drag/hit-test state machine that
reaches into bar internals:

```
bar.checkPopout    bar.clampedWidth   bar.closeTray         bar.dragThreshold  bar.handleWheel
bar.implicitWidth  bar.isHovered      bar.minHoverThreshold bar.popouts        bar.showOnHover
```

Both forks modified `Interactions.qml` differently (OP +61/-7, MiDnight +94/-32), so each extended
this contract in its own direction.

**Rule:** the bar is not swappable — there is one bar. Bar *components* (Dock, Spotify, Github,
status icons) are the unit of choice, and they map almost 1:1 onto upstream's planned plugin entry
points (`BarEntry`, `BarPopout`, `StatusIcon`). Keep them shaped that way so they can migrate later.

---

## T3 — OP's pattern lock is a lock-screen bypass — RELEASE BLOCKER

`modules/lock/center/PasswordInput.qml`:

```qml
readonly property string patternCode: GlobalConfig.lock.pattern ?? "74159"
readonly property bool patternAvailable: true          // hardcoded, ignores enablePattern

onPatternFinished: code => {
    if (code === root.patternCode) {
        root.lock.lock.unlock();                        // direct unlock, PAM never consulted
        return;
    }
    triggerError();
    root.lock.pam.rejectPattern();
}
```

`plugin/src/Caelestia/Config/lockconfig.hpp`:

```cpp
CONFIG_GLOBAL_PROPERTY(bool, enablePattern, true)
CONFIG_GLOBAL_PROPERTY(QString, pattern, u"74159"_s)
```

Four separate defects:

1. The unlock secret is stored **plaintext** in `~/.config/caelestia/shell.json`, readable by any
   process running as that user.
2. The success path **bypasses PAM entirely** — no attempt counting, no lockout, no `faillock`, no
   audit trail.
3. `patternAvailable` is hardcoded `true`, so the grid toggle is reachable even when `enablePattern`
   is false.
4. The default `"74159"` is a published constant. Any unconfigured OP install unlocks with it.

**Minimum bar before this ships:** salted hash (argon2id), honour `enablePattern`, no default value,
attempt limiting with password fallback, and require a password on first unlock after boot/suspend.
Preferred design: pattern is a convenience gate *in front of* PAM, never a replacement for it.

Dropping the feature is a legitimate alternative and costs nothing else in the project.

---

## T4 — `configDir()` is hardcoded; directory naming does not isolate a dev instance

`plugin/src/Caelestia/Config/common.cpp`:

```cpp
QString configDir() {
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + u"/caelestia"_s;
}
```

Installing QML to `~/.config/quickshell/caelestia-hybrid` still reads the **same**
`~/.config/caelestia/shell.json` as the user's working shell. A dev instance will fight their daily
driver over one file.

- **Workaround in use:** `hybrid/tools/dev-shell.sh` overrides `XDG_CONFIG_HOME`.
- **Proper fix (small, upstreamable):** make `configDir()` honour `$CAELESTIA_CONFIG_DIR`.

---

## T5 — Singletons are lazy, but shadowing one does not work

Good news: QML singletons are lazily instantiated. `ServiceLoader.qml` exists precisely to *force* a
handful to load early (`IdleInhibitor; GameMode; Notifs; Players; Brightness;`). An unreferenced
service is never constructed, so dead variant code costs nothing at runtime.

Bad news: `qs.services.Colours` and `qs.variants.midnight.services.Colours` are **different types**.
Anything importing `qs.services` gets the shared one. You cannot shadow a singleton to change
behaviour for one consumer — the change must go into the single shared service, gated by config.

This is why decision D5 exists: **merge services, do not fork them.**

---

## T6 — `services/Wallpapers.qml` state model *is* the feature

MiDnight rewrote it 125 → 486 lines with new singleton state: `wallpaperMode`, `previewPath`,
`rollbackPath`, `isTrackingRollback`, `cacheBuster`, `_hashCache`, video detection, categories.

Splitting wallpaper into selectable sub-implementations (renderer / browser / transitions / video /
auto-pause / wallhaven / palette extraction) would mean seven implementations of one singleton's
state. **Rejected.** Wallpaper is one implementation with config options.

---

## T7 — Both forks wrote code upstream has since replaced

- `services/NetworkUsage.qml`: both forks added it; upstream landed
  `feat(services): migrate NetworkUsage from QML to C++ (#1860)` after both fork points.
  On the Phase 2 merge, **delete both QML copies and take upstream's C++**.
- MiDnight's per-monitor config (`monitorconfigmanager.cpp`, `ConfigList`, `PerMonitorStatusChip`,
  `MonitorTargetSelector`) is superseded by upstream's `Settings/layerregistry.hpp` +
  `ConfigRoot::forScreen()`. **Take upstream's, drop MiDnight's.**

Before re-landing any fork feature, check whether upstream has since implemented it natively.

---

## T8 — `services/Audio.qml` conflicts are cosmetic; keep both sides

- OP adds `getStreamTitle()` / `getStreamIcon()` — per-app audio display.
- MiDnight adds `playLock()` / `playUnlock()` / `playCameraClick()` … — sound effects via
  `QtMultimedia`.

Different concerns, both purely additive, hunks textually adjacent (OP `@@ -104,2 +105,93`,
MiDnight `@@ -107,0 +109,44`). Git reports a conflict; the resolution is **keep both**.

This is the template for most service conflicts in this project. If a service conflict looks like it
needs a decision, re-read it — usually it does not.

---

## T9 — MiDnight ships with CI disabled

```
.github/workflows/  build-nix.yml
                    check-format.yml.disabled
                    lint.yml.disabled
                    release.yml.disabled
                    update-flake-inputs.yml.disabled
                    update-image.yml.disabled
```

33.5k lines that are not `qmllint`-clean and not `clang-format`-clean. Re-enabling in Phase 0 will
surface a backlog — budget for it, and fix rather than re-disable.

**Measured backlog** (`scripts/qml-lint-conventions.py`, same script in all three trees):

| Tree | Violations | Changed lines | Density |
|---|---|---|---|
| upstream | **0** | — | clean |
| OP | 227 | +8892 | 1 per 39 |
| MiDnight | 1034 | +33543 | 1 per 32 |

Entirely fork-introduced, and of similar density in both — this is not evidence the baseline
choice was wrong. `--fix` cleared 540 of MiDnight's (all `missing-section-separator`,
`import-order`, `file-structure`) and is already applied. **494 remain**: 489 `section-order`
plus 5 `blank-before-close-brace`, which the fixer deliberately leaves alone because they move
code rather than whitespace.

Two notes for whoever finishes this:

- Running the fixer on Windows rewrites files as CRLF (`Path.write_text` uses `os.linesep`).
  Normalise afterwards.
- Only **2 files** overlap between the violation set (88 QML files) and the incoming upstream
  range (22 QML files) — `services/Colours.qml` and `shell.qml`. So a style pass does *not*
  meaningfully increase Phase 2 conflict surface; upstream's churn is 159/197 files in C++.
  Do not defer the cleanup out of merge-conflict fear.

**`qmllint` is a second, larger backlog** (measured 2026-09-02 on CachyOS, Qt 6.11.2, against a
real build — use `/usr/lib/qt6/bin/qmllint`, see T13):

| Category | Count |
|---|---|
| `unqualified` | 573 |
| `unused-imports` | 125 |
| `missing-property` | 78 |
| `unresolved-type` | 11 |
| others (`equality-type-coercion`, `property-override`, `incompatible-type`, …) | ~25 |

~810 warnings total. Upstream's `lint.yml` fails on **any** output, so this must reach zero before
that gate can go green. `unqualified` dominates and is largely mechanical — it wants `root.`
prefixes or `pragma ComponentBehavior: Bound` — but unlike the convention fixer there is no
`--fix`, and it genuinely changes code, so it needs the smoke matrix behind it.

Treat these as two separate burn-downs: conventions (494 left, mechanical) and qmllint (~810,
needs review). Neither blocks Phase 2; both block a green CI badge.

**MiDnight only disabled the workflows; it did not weaken them.** `lint.yml` and
`check-format.yml` are byte-identical to upstream at the merge base `ad8dca0a`. The `lint-cpp`
clang-tidy job that upstream's current `lint.yml` has was added on 2026-09-01
(`5f37c31e chore: add clang tidy (#1920)`), *after* MiDnight's fork point — it was never removed.
It arrives naturally in the Phase 2 merge. Do not backport it early: running
`-warnings-as-errors='*'` against pre-rewrite C++ produces noise from code that is about to be
replaced.

Not every disabled workflow should come back:

| Workflow | Phase 0 action |
|---|---|
| `check-format.yml`, `lint.yml` | **Re-enable** — quality gates |
| `release.yml` | Leave off until there is a release process; wants `contents: write` |
| `update-flake-inputs.yml` | Leave off — weekly bot that commits to the repo, needs an app token |
| `update-image.yml` | **Leave off permanently** — publishes `shell-arch-env` to the fork owner's ghcr; we consume upstream's image instead |

Both quality gates reference `ghcr.io/${{ github.repository_owner }}/shell-arch-env:latest`. A fork
does not publish that image, so the templated owner resolves to nothing and the job cannot start.
Repoint to `ghcr.io/caelestia-dots/`. OP hit this and fixed it the same way.

---

## T10 — Config schema is compiled C++, not dynamic JSON

Adding a setting is not "add a JSON key". It is a macro in a `*config.hpp`, registration on the
config root, and Nexus UI wiring. See the `config-property` skill.

Unknown JSON keys do not become config properties — upstream's `Settings/quarantine.cpp` sets aside
what it cannot place. A hand-edited `shell.json` key that never appears in the UI is this, not a bug.

---

## T11 — Upstream's plugin system is coming and overlaps with our feature flags

`caelestia/feat/plugins` is a real system: manifests, hot reload, a URL interceptor, per-plugin
settings plus settings UI, and typed entry points (`Custom`, `BarEntry`, `BarPopout`, `StatusIcon`,
`QuickToggle`, `DashboardTab`). As of 2026-09-02 it is 51 commits ahead of `main` and **64 behind**,
and is built on the *old* config module, so it needs rework before it lands.

It cannot host a dock, lockscreen, or wallpaper backend — the entry points do not exist. But when it
does land, anything we built as a bar entry, popout, status icon or quick toggle should migrate onto
it. Shape those features accordingly and avoid inventing a competing manifest format.

---

## T12 — `QT_QPA_PLATFORM=offscreen` cannot boot this shell

Quickshell's `PanelWindow` is a **wlr-layer-shell** surface. With no Wayland backend the type is
unavailable, and because Quickshell resolves the `services/` singletons as one graph, a single
`PanelWindow` failure cascades into everything:

```
Failed to load configuration
  caused by @shell.qml[37:5]: Type ServiceLoader unavailable
  caused by @services/Audio.qml: Type Brightness unavailable
  … 12 more …
  caused by @services/NotifData.qml[67:9]: No PanelWindow backend loaded.
```

**Read that cascade bottom-up.** The last line is the cause; everything above is fallout.

Upstream's `lint.yml` *does* run `QT_QPA_PLATFORM=offscreen … qs -p .`, which is what misled us.
It sits under `# Generate tooling`, exists only to emit `.qmlls.ini` for the linter, and its exit
code is never checked — it is *expected* to fail this way.

`hybrid/tools/smoke-matrix.sh` therefore spawns a nested Hyprland. Notes:

- Hyprland has **no headless flag**, and aquamarine has **no `AQ_BACKENDS` env var** (checked with
  `strings` on `libaquamarine.so`). It auto-selects: Wayland if `WAYLAND_DISPLAY` is set, else DRM.
  With neither it dies with `CBackend::create() failed!`.
- `--socket NAME` does **not** name a new socket; it requires `--wayland-fd` and is for socket
  handover. Let Hyprland pick, then diff `$XDG_RUNTIME_DIR/wayland-*` before and after.
- CI has neither a parent display nor a free DRM device, so Hyprland cannot run there at all.
  Confirmed: `XDG_BACKEND=headless`, `WLR_BACKENDS=headless` and a bare run with `WAYLAND_DISPLAY`
  and `DISPLAY` unset all abort in `CBackend::create()`. Aquamarine *has* a `CHeadlessBackend`,
  but it is a fallback for output management, not a backend you can select.

**CI runs headless sway instead** (`--compositor sway`, `.github/workflows/smoke.yml`). It is
wlroots, it implements wlr-layer-shell — the only protocol `PanelWindow` needs — and
`WLR_BACKENDS=headless` needs no display. Three things are load-bearing:

- **`WLR_RENDERER=pixman`.** With the GL renderer a headless output has no scanout buffer, so the
  client dies *after* loading successfully:
  `importing the supplied dmabufs failed` → `Could not create EGL surface (EGL error 0x3000)` →
  `The Wayland connection experienced a fatal error: Protocol error`. Easy to misread as a shell
  bug; it is not.
- **`XDG_RUNTIME_DIR`.** A CI container has none and no `/run/user/<uid>`. `smoke-matrix.sh`
  creates a private one when the configured path does not exist.
- **A separate ignore list.** Sway advertises none of the `hyprland-*` protocols and a container
  has no GPU, PipeWire or session bus, so `hybrid/tools/smoke-ignore-headless.txt` is applied on
  top of the main list *only* under `--compositor sway`.

Sway is a **narrower gate**: everything behind `Hypr.*` is inert there, including the lua/conf
axis of T17. It still catches load errors, unresolved types and binding errors across every
preset, which is most of the value. Hyprland stays the default wherever a display exists, and
`smoke-matrix.sh` falls back to sway on its own when there is none.

---

## T13 — `/usr/bin/qmllint` is not Qt's qmllint

On Arch/CachyOS, `/usr/bin/qmllint` is an unrelated tool that reports `qmllint 1.0` and rejects
`--import`. Qt's is at `/usr/lib/qt6/bin/qmllint` (6.11.2 here). Identical situation for
`qmlformat`. This is exactly why upstream CI hardcodes `/usr/lib/qt6/bin/`.

A run that "passes" with one line of output and exit 1 is this, not a clean tree.

Related: the Bash tool on this machine runs **zsh**, so `mapfile` and `read -ra` fail in inline
commands. Wrap them in `bash -c '…'`. The repo's own scripts are unaffected — they have
`#!/usr/bin/env bash` shebangs.

---

## T14 — MiDnight's `Settings` persistence silently does not work

`services/Wallpapers.qml` and `services/WallpaperPauser.qml` are the **only** files across all
three trees that use QtCore's `Settings` type. Quickshell never calls
`QCoreApplication::setOrganizationName`/`setApplicationName`, so QSettings fails to initialise:

```
QML Settings at @services/Wallpapers.qml[383:5]: Failed to initialize QSettings instance. Status code is: 1
The following application identifiers have not been set: QList("organizationName", "organizationDomain")
```

Wallpaper-engine volume/silent and the pauser's settings therefore never persisted across restarts.

Adding an explicit `location:` does **not** help — `WallpaperPauser` already had one and still
failed, which is the clue: the failure is at QSettings construction, before the location matters.

**Fixed** in `plugin/src/Caelestia/Config/appidentity.cpp`, a `Q_COREAPP_STARTUP_FUNCTION` that
fills in `organizationName` and `organizationDomain` (and `applicationName` if a host ever leaves
it empty). Quickshell sets `applicationName` to `quickshell` and nothing else, so supplying the
missing half is the entire fix. Verified by running with a fixed `XDG_CONFIG_HOME` and reading the
file back:

```
$XDG_CONFIG_HOME/caelestia/quickshell.conf
  [General]          silent=false  volume=0.15
  [WallpaperPauser]  hwDecoder=none  manualPause=false  pauseOnBattery=false  pauseOnWindowOverlap=true
```

Note the pauser's values land in that file rather than the `location:` it asks for — the location
is still not applied. They persist, which was the bug; where exactly is cosmetic.

---

## T15 — MiDnight deleted `assets/wallpaper.webp` but kept the reference

Fixed 2026-09-02, recorded because it is the shape of bug to expect from the baseline.

`326d9090 "Add multiple featured wallpapers to wallpaper picker"` removed `assets/wallpaper.webp`
(present in upstream and OP, 5.5 MB) and added `assets/wallpapers/*.png`. But
`services/Wallpapers.qml:18` still pointed `fallback` at the deleted file, and `fallback` is used
in four places — including `caelestia wallpaper -f "$fallback"`, so a fresh install asked the CLI
to set a nonexistent wallpaper.

Now points at `assets/wallpapers/Gravitation.png`. Found by the very first smoke run.

---

## T16 — `qmllint` reports imports as unused that are actually required

Two files in the tree hit a `qmllint` 6.11.2 false positive: the import is reported as
`[unused-imports]`, and deleting it turns every use of the singleton it provided into
`[unqualified]`. The linter contradicts itself.

| File | Import | Symbol | Uses |
|---|---|---|---|
| `modules/Shortcuts.qml` | `Caelestia.Config` | `GlobalConfig` | 7 |
| `modules/launcher/services/Animations.qml` | `qs.utils` | `Paths` | 2 |

It is not simply "used only in a template literal" — that alone is credited correctly. A minimal
reproducer, linted with the project's own import paths:

```qml
Item { property string a: `${Paths.config}/x` }        // clean
Item { property string a: Paths.config + "/x" }        // clean
Item { property string a: `${Paths.config}` + "/x" }   // FALSE "Unused import"
```

Both real cases use the singleton only inside JS statement bodies or an array literal, never in a
plain property binding.

**Handling.** Keep the import and silence the one line:

```qml
import Caelestia.Config // qmllint disable unused-imports
```

Before adding one of these, *prove* it: delete the import, re-lint the file, and confirm you get
`Unqualified access` on the symbol. If you don't, the import really is unused — remove it.

**Consequence for bulk cleanup.** Do not trust `[unused-imports]` in bulk. Remove, re-lint the
whole tree, and diff the diagnostics by `(file, message, category)` rather than by line — line
numbers shift under you. A removal that introduces *any* new `unqualified` or `unresolved-type`
was wrong. Cross-check the pre-existing `unqualified` list too: if a symbol was already unresolved
before the removal, breaking it further produces no new diagnostic and the diff will not see it.

---

## T17 — `Hyprland.usingLua` is false for the first moments after startup

Hyprland 0.56 reads a Lua config when it finds one and calls the ini format **legacy** in
its own logs. The two are not interchangeable at the IPC layer. Measured on 0.56.2 against
a nested instance:

| command | conf config | lua config |
|---|---|---|
| `dispatch workspace 2` | ok | **error** — "dispatch in lua is a shorthand for `hl.dispatch(...)`" |
| `keyword general:gaps_in 7` | ok | **error** — "keyword can't work with non-legacy parsers. Use eval." |
| `dispatch 'hl.dsp.focus({ workspace = "3" })'` | error | ok |

The shell picks a spelling from `Hyprland.usingLua` in **40 places across 17 files**. That
property works — but it is populated asynchronously, after Quickshell's IPC handshake:

```
PROBE init  usingLua = false      # Component.onCompleted
PROBE tick  usingLua = true       # 3s later, lua config
PROBE tick  usingLua = false      # 3s later, conf config
```

**Anything that dispatches during startup therefore takes the legacy branch regardless of
the real config.** `services/Colours.qml:130` does exactly that:

```qml
Component.onCompleted: root.requestReloadHyprRules()
```

and the first call is not debounced, so on a Lua setup it sent
`keyword layerrule blur ..., match:namespace caelestia-drawers` — which Hyprland rejects.
Blur and `ignore_alpha` for the drawers, polkit and desktop-lyrics layer surfaces were
silently never applied.

Fixed by resending from `onUsingLuaChanged` on the `Hypr` singleton. Verified by
instrumenting the handler and booting under each config:

```
lua   TMPPROBE onCompleted, usingLua = false
lua   TMPPROBE onUsingLuaChanged fired, usingLua = true     <- resend, correct spelling
conf  TMPPROBE onCompleted, usingLua = false                <- correct already, no resend
```

**Connect to `Hypr`, not to `Hyprland`.** Quickshell's `usingLua` is a
`QObjectBindableProperty`; a QML binding on it re-evaluates, but
`Connections { target: Hyprland; function onUsingLuaChanged() }` never fires. `Hypr`
re-exposes it as an ordinary QML property (`readonly property bool usingLua:
Hyprland.usingLua`), whose change signal does. Both were tested.

`smoke-matrix.sh` boots under a Lua config by default and takes `--hypr conf` / `--hypr
both`. Note what that does and does not cover: the axis genuinely flips `usingLua`, but
nearly every one of the 40 branch sites is inside a click handler, so a boot smoke reaches
almost none of them.

---

## T18 — qmllint lints against the *installed* shell, not the one you built

`qmllint` always consults Qt's default QML import directory, and it does so **in preference
to every `-I` path you pass**. This machine has `midnight-shell-git` installed, which ships
`/usr/lib/qt6/qml/Caelestia/` — the pre-Phase-2 plugin layout. So the linter was resolving
`Caelestia.*` types from the *package*, not from `./build/qml`.

While the two layouts agreed this was invisible. After the upstream config rewrite moved
types between modules it produced a contradiction that looks like a qmllint bug and is not:

```
Info:    Unused import [unused-imports]          import Caelestia.Images
Warning: Cannot resolve alias "wallLuminance"    analyser.luminance
```

The import is "unused" because `ImageAnalyser` was never found in it — the installed
`Caelestia.Images` has `IUtils` but not `ImageAnalyser`, which in that layout lives in the
root `Caelestia`. `IUtils` resolved; `ImageAnalyser` did not; same module, same file.

**`--bare` is the fix.** It drops the default import directory, after which `-I` order is
honoured and `./build/qml` wins. `hybrid/tools/qml-lint.sh` passes it. To reproduce the
problem, drop the flag.

**Two things this hid.** First, `--import disable` — which upstream's CI passes and which
this project copied — silences the whole `import` category, so `ImageAnalyser was not
found` never printed and only the "unused import" symptom did. When an unused-import report
makes no sense, re-run without `--import disable` before believing it.

Second, and worse: `qml-lint.sh --summary` counted diagnostics with `\[[a-z0-9-]+\]$`,
which does not match the qmllint Quick plugin's `[Quick.property-changes-parsed]` or
`[syntax.duplicate-ids]`. It reported **`clean, no warnings` on a tree that had 60 of
them**, including two duplicate-id *errors*. The exit code was right — that path measures
output size — so the gate itself never passed falsely, but the summary did, and it was
believed. The class is now `[A-Za-z0-9.-]+`.

Anything counting compiler or linter output needs its category pattern checked against real
output containing every category, not against the categories you expect.

---

## T19 — `-Werror` is a CI gate, and it had never been run here

**Symptom:** none locally. `cmake --build build` is green, every lint is zero, and
`.github/workflows/build.yml` still fails on both of its legs.

`build.yml` builds twice — `g++` and `clazy` — and both pass `-DCMAKE_CXX_FLAGS=-Werror`.
Nothing in this project's tooling did, so the flag was never exercised. On first run:

| leg | errors | where |
|---|---|---|
| `g++ -Werror` | 11 | `QuickShareCrypto.cpp`, deprecated OpenSSL 3.0 `EC_KEY` API |
| `clazy -Werror` | 9 + a truncated tail | 5 files, plus every generated `.pb.cc` |

Three separate lessons came out of it.

**A gate you inherit is not a gate you pass.** Four static gates were brought to zero in
Phase 0 and CI was described as green. The two `-Werror` build legs were part of that CI
the whole time and had simply never been invoked locally.

**`-Werror` is compiler-specific, so one compiler proves nothing.** Every `clazy` finding
was invisible to `g++`: `-Wnullability-extension` does not exist there, and the
`clazy-*` checks are a clang plugin. Run both legs or neither.

**A truncated error list hides its own size.** clang stops at `-ferror-limit=20`. The first
clazy run reported 3 distinct warnings; after fixing them the next run found 3 more, and
only the run after that was clean. Re-run until a *clean* run, never until a *short* one.

### What the findings actually were

`QuickShareCrypto.cpp` carried a TODO saying the `EC_KEY` migration could not be verified
because "nothing in this tree can exercise a real Quick Share transfer". That was true of a
*transfer* and false of the *handshake* — see T20.

The generated `.pb.cc` files are not ours to lint; `plugin/src/Caelestia/Services/CMakeLists.txt`
now sets `COMPILE_OPTIONS "-w"` on `${PROTO_SRCS}`. Use `-w` rather than naming the specific
warning: the set changes with the protoc and compiler version, and `-w` is understood by
gcc, clang and clazy alike.

The rest were real and each had a truthful fix rather than a suppression:
`Q_PROPERTY(... CONSTANT)` for the three BlueZ advertisement properties (BlueZ reads them
once at `RegisterAdvertisement`, and all three are literals), `QDateTime::currentSecsSinceEpoch()`
for `currentDateTime().toSecsSinceEpoch()`, and a `const` binding for two range-loops that
were detaching a Qt container.

### clang-tidy's build directory must be NAMED "build"

Two filters act on it and they want different things, which is easy to satisfy by halves:

| | pattern | `build` | `tidy-build` |
|---|---|---|---|
| generated **headers** | `.clang-tidy`'s `ExcludeHeaderFilterRegex: 'build/.*'` — unanchored | excluded | excluded |
| generated **sources** | CI's `-source-filter='^(?!.*/build/).*\.cpp$'` — needs a literal `/build/` | excluded | **not excluded** |

Satisfy only the first and Qt's own generated `.cpp` get linted as project sources:
`mocs_compilation.cpp`, `caelestia-*_qmltyperegistrations.cpp` and the `qrc_qmake_*.cpp`
resource files. Measured on the same tree with the same command: **316 diagnostics from
`tidy-build`, 0 from `build`**, dominated by `readability-identifier-naming` and
`bugprone-suspicious-include` on code moc wrote.

`hybrid/tools/verify.sh` got this wrong on its first run, and so did the earlier version of
this trap, which said the name merely had to *end* in "build". Nested is fine —
`.verify/build` satisfies both, because the component is what matters, not the prefix.

Note that protoc's output escapes on a technicality rather than by design: `.pb.cc` does not
match `\.cpp$`. Do not rely on that; the extension list is CI's, not ours.

### And a local-only hazard found on the way

A `build/` directory configured with one compiler and later reconfigured with another keeps
the *first* compiler's interface flags and PCH targets. A `build/` that had seen `g++` and
was then pointed at `clang++` produced `error: unknown argument: '-mno-direct-extern-access'`
on 126 of 127 entries. Configure a fresh directory per compiler; do not reuse one.

That flag is not noise, incidentally: Arch's Qt6 is built with `-mno-direct-extern-access`
and anything linking Qt must be too, or the link fails with `copy relocation against
non-copyable protected symbol '_ZN10QByteArray6_emptyE'`. `hybrid/tools/plugin-test.sh`
passes it for that reason.

---

## T20 — The QuickShare handshake is testable without a phone

**Symptom:** hand-rolled crypto with no coverage, and a TODO saying it cannot be covered.

QuickShare's UKEY2 implementation is ~500 lines of imported OpenSSL: an ECDH exchange, an
HKDF ladder deriving four keys and a PIN, and AES-256-CBC payload encryption. Nothing
exercised any of it. The stated reason was that checking it meant sending a real file from
a real phone.

It does not. `QuickShareCrypto` is a plain class with no transport in it, so two instances
can be handed each other's messages directly:

```
client.generateClientInit()  ->  server.processClientInit(...)
                             <-  returns the server init
client.processServerInit(...) ->  returns the client finish
                             ->  server.processClientFinished(...)
```

After that the invariants are all locally checkable, and they are what the protocol is
*for*: each side's encode key equals the other's decode key, the two directions use
different keys, both sides derive the same PIN, a payload round-trips both ways, a third
party running the same exchange derives different keys, and malformed input leaves
`isHandshakeComplete()` false rather than half-completing.

`hybrid/tools/plugin-test.sh` runs 50 rounds of that plus the negative cases. It is how the
OpenSSL 3.0 migration in T19 was verified, and it found the `-mno-direct-extern-access`
link requirement on the way.

**The generalisable part:** "this needs real hardware to test" is usually a claim about the
*transport*, not about the logic underneath it. Check whether the logic is separable before
accepting it. Here the class had no I/O in it at all.

---

## T21 — `BeatTracker::beat` was declared, connected to, and never emitted

**Symptom:** the dashboard's media shapes morph on a timer instead of on the beat, and
drift out of phase with the music. No warning, no error, no lint finding.

`plugin/src/Caelestia/Services/beattracker.hpp` declares the signal twice, on two different
classes:

```cpp
class BeatProcessor : public AudioProcessor { signals: void beat(smpl_t bpm); };
class BeatTracker   : public AudioProvider  { signals: void beat(smpl_t bpm); };
```

`BeatProcessor::beat` is emitted from `process()` and connected to `BeatTracker::updateBpm`.
`BeatTracker::beat` — the one QML can see, because `BeatTracker` is the `QML_ELEMENT` — was
emitted by nothing, in **all three upstreams**. Meanwhile
`modules/dashboard/dash/MediaShapes.qml` has been connecting to it the whole time:

```qml
Connections {
    function onBeat(bpm) { materialShape.morph(); }
    target: Audio.beatTracker
}
```

The fix is to forward it. `updateBpm` cannot stand in: it only signals when the bpm
*changes*, and a beat happens on every beat. `hybrid/tools/tests/beat-signal.cpp` measures
exactly that distinction — against `HEAD` before the fix it reports `beat fired 0/3`, and
after it reports `beat fired 3/3 at 128.0 bpm, bpmChanged fired 1/1`.

**Why nothing caught it.** A QML `Connections` handler for a signal that exists but never
fires is valid QML and valid C++. qmllint resolves the signal, so there is nothing to warn
about; the C++ side has a declared signal with no emitter, which no compiler diagnoses
because moc generates a perfectly good emitter for it. The only way to see it is to ask
"what emits this?" — worth asking of any signal a QML file handles.

`hybrid/tools/dead-signals.py` now asks it for all 209 of them, and runs first in
`lint.yml`'s `lint-cpp` job because it needs no build. Against `7f1ec1fe~1` it reports
`DEAD BeatTracker::beat`; against the current tree, nothing.

**It has to be generous, and here is what that costs.** A false positive sends someone to
"fix" working code, so four things count as an emitter, and a first cut that missed any of
them produced only false alarms:

| looks dead | actually | seen in |
|---|---|---|
| `usingLuaChanged` | moc emits the NOTIFY of a `MEMBER` property on write | `HyprExtras` |
| six `AppEntry` `*Changed` | forwarded via the runtime metaobject API, which no source scan can follow: `connect(m_entry, metaProp.notifySignal(), this, thisMetaProp.notifySignal())` | `AppEntry` |
| `rawDeformMatrixChanged` | emitted by a *subclass* — declared on `BlobShape`, emitted four times in `BlobRect` | `BlobShape` |

The last one is the reason the checker resolves inheritance rather than matching on the
declaring class. The first version of it keyed on the signal *name* globally, which is worse
still: it would have called `BeatTracker::beat` live, because `BeatProcessor::beat` — a
different class, in the same header — is emitted. **A checker for this has to be class-aware
and inheritance-aware, or it silently misses the exact case it was written for.**

---

## T22 — `chmod +x` does not reach the index, because `core.fileMode` is false

**Symptom:** a script you can run all day locally fails in CI, or for anyone who clones,
with `Permission denied`. `git status` is clean. `ls -l` shows `-rwxr-xr-x`.

This repository sets `core.fileMode = false`, and it has to. Turning it on reports **419
mode-only differences** — the working tree carries exec bits the index does not, and every
real diff would be buried under the noise. So the setting is right, and the consequence is
that `chmod +x` on a new file silently does nothing git will ever record. It is committed
`100644` and nothing says so.

Four tools were already committed that way: `qml-lint.sh`, `qml-section-order.py`,
`plugin-test.sh` and `dead-signals.py`. The shell-verify gate invokes all four as
`./hybrid/tools/...`, so a clean checkout would have failed on the first two steps of the
gate, and CI would have failed on `plugin-test.sh` the first time it ran.

**The fix is `git update-index --chmod=+x <path>`**, not `chmod`. `chmod` is what does not
work here, and it is the thing everyone reaches for.

`hybrid/tools/check-index-modes.sh` fails on any tracked file that starts with `#!` and is
not `100755`. It runs first in `smoke.yml`, before anything can invoke a script.

One implementation note, since it bit while writing it: testing the first two bytes with
`case $(head -c 2 "$f")` makes bash warn `ignored null byte in input` on every binary file
in the repo. `head -n 1 "$f" | grep -qa '^#!'` avoids the command substitution and stays
quiet.

---

## T23 — A gate nobody has watched fail is not known to work

Three of this project's gates turned out to have no teeth, in three different ways, and
none of them looked broken:

- **`build.yml`'s two `-Werror` legs** had never been run locally at all. They were red the
  whole time CI was described as green (T19).
- **A hand-rolled gate script** printed `diagnostics: 0` for each `-Werror` leg without ever
  setting its failure flag, so it could have reported GREEN over a red leg. It was caught
  only because an unrelated step happened to be red at the time and made the overall verdict
  disagree with the step output.
- **`qml-lint.sh --summary`** counted diagnostics with a regex that missed two whole
  categories and printed `clean, no warnings` over 60 real ones (T18).

The smoke matrix is the one that would hurt most. It works by copying a preset to
`shell.json` and failing on what the log says — so if a preset were silently rejected, the
shell would boot with defaults, the log would be clean, and the matrix would report six
presets passing while testing one config six times.

It does not: `settings::Node` warns on unknown keys, wrong types and bad enum values, and
the harness treats those warnings as failures. That was a guess until it was measured, and
measuring it is now `--self-test`:

```
./hybrid/tools/smoke-matrix.sh --self-test
```

It feeds the harness a config that is valid JSON and invalid schema — a misspelled enum
value, an unknown section, an unknown key, a wrong type, an unknown top-level key — and
passes only when the run **fails**. It runs in CI immediately before the matrix it
validates.

The self-test has teeth of its own, which was also measured rather than assumed: appending
`caelestia.settings` to `smoke-ignore.txt` — the one edit that would blind the matrix to
exactly this — makes `--self-test` report FAIL.

**The general rule:** when you add or inherit a gate, make it fail once on purpose before
you trust a pass. `smoke-ignore.txt` deserves particular suspicion, because every line in it
is a deliberate blindfold and a line that is slightly too broad is invisible.

So the ignore list audits itself now too:

```
./hybrid/tools/smoke-matrix.sh --audit-ignores
```

It reports how many log lines each pattern matched, and never fails the run — several
entries are legitimately intermittent, so a zero is a prompt to check, not a verdict. Its
first run found 8 of 11 patterns load-bearing and 3 matching nothing:

- `caelestia.requests: \w+: request failed with error` — kept. The weather API 503s often
  enough to have failed 5 of 12 runs in one sitting; a zero here means a good day.
- the two `QObject: ... different thread` entries — deleted, and then **put back**. This is
  the interesting one, and it is a mistake worth keeping written down.

### The ignore entries I deleted and had to restore

Both matched nothing across 12 runs, and both named a Qt-wide diagnostic rather than one
known instance, so deleting them looked like restoring coverage at no cost. The matrix then
ran 12/12 clean without them, which seemed to settle it.

A later run failed **12/12** on exactly those two lines. The full message, which the earlier
comment had never quoted, says what is actually happening:

```
QObject: Cannot create children for a parent that is in a different thread.
(Parent is QGuiApplication, parent's thread is QThread, current thread is QQuickPixmapReader)
```

`QQuickPixmapReader` is Qt Quick's internal image-loading thread. The entry had been
attributed to "QuickShare's worker thread during teardown" — which the message contradicts,
and which nobody had checked. It fires beside the first image load, it is Qt's own code, and
there is nothing here to fix.

Two separate errors, and the second is the one that matters:

1. **The attribution was never verified.** A one-line justification on an ignore entry is
   worth exactly as much as the evidence behind it, and this one had none.
2. **Zero matches is a sample, not a proof.** The condition is a race against startup timing.
   Twelve quiet runs said the race had been landing the other way, not that it was gone —
   and the thing that flipped it was unrelated: deleting four dead QML files changed startup
   timing enough to change the outcome.

So the audit question is sharper than "does this still fire" and sharper than "would I want
to know if it came back". It is: **do I have a reason this condition cannot recur?** For a
race, a run of quiet days is never that reason. Delete an entry when the code that produced
it is gone, not when the log happens to be quiet.


---

## T24 — A `NOLINTNEXTLINE` silently detaches when you insert anything above its target

**Symptom:** a suppression that has worked for months stops suppressing, and the check it
was hiding reappears somewhere unrelated — or, worse, starts covering a different function.

`NOLINTNEXTLINE` binds to *the literal next line*, comment lines included. It has no idea
what function it was written for.

Both failure modes happened here, in the same file:

**Detached by an insertion.** `handlePayloadTransfer` carried a
`NOLINTNEXTLINE(readability-function-cognitive-complexity)`. Extracting `sendOutgoingFile()`
and placing it above `handlePayloadTransfer` put a new function *between* the comment and
its target. The suppression then pointed at `sendOutgoingFile`'s leading comment line, which
suppresses nothing at all, and `handlePayloadTransfer` was reported again. Nothing warned:
an unused NOLINT is not a diagnostic by default.

**Detached by a comment.** Four suppressions written as a two-line comment — the reason on
the first line, `NOLINTNEXTLINE` on the second — were fine, but four written the other way
round, with prose *after* the marker, silently did nothing.

**What to do instead.** Prefer removing the cause. Every cognitive-complexity suppression in
this tree is gone now, not because they were re-anchored but because both functions were
split: 28 → under 5 for `onServiceResolved`, 70 → 9 for `handlePayloadTransfer`. When a
suppression is genuinely right, keep it on the line immediately above its target with the
explanation *above* the marker, never between it and the code.

The reason this is worth a trap rather than a note: a detached suppression fails in the
direction that looks like a new bug. The check fires on code that has not changed, on a
commit that did not touch it, and the natural reading is that the refactor caused it.

---

## T25 — `qs ipc call` always exits 0, including when it did nothing

**Symptom:** a script drives the shell over IPC, checks `$?` after every call, reports
success, and half the calls never ran.

Measured against a live shell:

| call | output | exit code |
|---|---|---|
| `ipc call wallpaper get` | the wallpaper path | **0** |
| `ipc call wallpaper getNoSuchThing` | `Function not found.` | **0** |
| `ipc call noSuchTarget nope` | `Target not found.` | **0** |
| `ipc call mpris getActive` (arity) | `Too few arguments provided (1 required but 0 were provided.)` | **0** |

The error goes to the output. The exit status is success in every case. So `if ! out=$(... )`
is not a check, and neither is `set -e`.

The smoke drive made this maximally invisible by redirecting both streams to `/dev/null`,
which is reasonable for a drive — the point is to exercise code, not to read results — right
up until a call is wrong. Two were, the day the drive was extended past the panels:
`mpris getActive` takes a property name and `hypr cycleSpecialWorkspace` takes a direction,
and both had been called bare. They exercised nothing and said nothing.

`check_ipc` in `smoke-matrix.sh` now runs every call in the drive and greps the *output* for
`Target not found.`, `Function not found.` and `arguments provided`, failing the run if any
appears. Verified with a deliberate typo, which the harness reports as
`ipc call 'wallpaper getNoSuchThing': Function not found.`

**What this bought immediately.** With all 54 IPC functions enumerated and the drive
converted, the six presets still pass — which establishes something that was only assumed:
`IpcHandler` targets are registered unconditionally, so turning a feature off does not remove
its IPC surface. A drive that calls `launcher openEmoji` under the `all-off` preset is still
making a real call.

**The general shape, again:** a tool that reports failure on a channel you are not reading is
indistinguishable from a tool that works. Check what a tool does on bad input before trusting
what it says on good input.

---

## T26 — Shell commands built by string concatenation, with remote data in them

**Symptom:** a wallpaper whose filename contains an apostrophe does nothing, or worse.

`Process.command` and `Quickshell.execDetached` both take an argv list, so a shell is
optional — but fourteen sites built one anyway by concatenating values into a `sh -c`
string. Single quotes around the value were the only barrier, and a `'` in the value ends
the quoting and returns to shell syntax. Measured, with the payload `'; touch pwned.txt;
echo '`:

```
old:  sh -c "... echo '$VALUE' > 'out.txt'"      -> pwned.txt created; arbitrary command ran
new:  sh -c '... printf "%s\n" "$2" > "$3"' sh "$VALUE" out.txt
                                                  -> nothing ran; out.txt holds the value verbatim
```

**Where the value comes from decides how bad it is.** Ten sites were changed, in three tiers:

| site | value | origin |
|---|---|---|
| `WallhavenSearcher.qml` download, move | `wallpaper.path`, `wallpaper.id` | **`JSON.parse` of the wallhaven.cc API response** |
| `Wallpapers.qml` ×3, `WallpaperItem.qml` | a wallpaper path | a filename on the user's disk |
| `Clipboard.qml` ×2, `ClipItem.qml` | cache dir, cliphist id | local — and `imageCacheDir` was not even quoted |

The Wallhaven pair is the one that matters: those values are attacker-influenced in the
ordinary sense, not just awkward.

**The fix is the pattern already in the tree.** `services/Nmcli.qml` was doing it right in
one place: `["sh", "-c", script, "sh", a, b]` passes `a` and `b` as `$1` and `$2`, which the
shell never parses as syntax. Where no shell is needed at all — the Wallhaven download was
just `curl` — the argv form replaces `sh` entirely.

`hybrid/tools/shell-safety.py` now enforces it, and runs in `lint.yml` beside the dead-signal
check because it needs no build either. Against the tree before the fix it reports 15 sites;
against the tree after, none. The allowlist is keyed by file and by a snippet of the line
rather than by line number, so it does not rot when something above it moves, and every entry
carries its reason.

Writing that checker took three attempts, and the two failures are the interesting part:

- Reading only the *literal* missed `"echo '" + value + "' > f"`, where the value is
  concatenated **outside** the quotes.
- Reading the whole *line* flagged the correctly-written calls, because a positional argument
  like `` `${Paths.state}/wallpaper` `` sits after the script and looks exactly like
  interpolation into it.

Neither mistake is visible from the output — one under-reports, the other cries wolf on the
fix. It has to parse the script argument as one expression, stopping at the comma that ends
it. Checked both ways before being believed.

**Not everything with `sh -c` is a bug.** Four uses are correct by design and were left
alone: `Keybinds.qml` runs the user's own keybind commands, which is the feature; the Hypr
config pages write user config through quoted heredocs; and `ArpcPage.qml` and
`BarGithub.qml` already pass secrets as `"--", token` with `<<< "$1"`. The question to ask
is not "is there a shell" but "does any value reach it as syntax".

**One instance was found and deliberately left.** `modules/launcher/items/CalcItem.qml`
interpolates the launcher's calculator expression into `fish -C "exec qalc -i '...'"`. A
value does reach the shell as syntax there, so it belongs on this list — but the value is
what the user just typed into their own launcher, and the launcher already runs arbitrary
commands by design, so no boundary is crossed. What is left is a robustness nit: an
apostrophe in an expression breaks the calculator. Fixing it properly means escaping for
*fish* rather than POSIX quoting rules, in a code path that spawns an interactive terminal
and so cannot be exercised by the harness. Recorded rather than changed blind.

---

## T27 — QuickShare can send but cannot receive: the prompt is never instantiated

**Symptom:** send a file from the shell and it works. Send one *to* the shell and nothing
appears, ever.

The C++ side of the incoming path is complete:

```cpp
// quickshare_service.hpp
void incomingTransferRequested(const QString& deviceName, const QString& fileName, qint64 fileSize);
void incomingTransferPinReady(const QString& pinCode);
Q_INVOKABLE void acceptIncomingTransfer();
Q_INVOKABLE void rejectIncomingTransfer();
```

Both signals are emitted, from `onNewConnection`. **Nothing in QML handles either**, and
nothing calls accept or reject, so an incoming transfer sits waiting for a confirmation that
can never arrive.

`modules/notifications/QuickSharePrompt.qml` is the UI for exactly this, complete with
Accept and Decline wired to those two invokables — and it is instantiated nowhere. It also
writes `QuickShare.hasPendingTransfer`, which is not a property of the service: the only two
references to that name in either tree are the two inside this file.

**This is inherited, not a merge regression.** It is equally dead in `dim-ghub/midnight-shell`:
the file exists, nothing instantiates it, and `hasPendingTransfer` is undefined there too. Our
merge carried it over faithfully.

**Why it is recorded rather than fixed.** Wiring it needs a `hasPendingTransfer` (or the
equivalent state in QML), a decision about where the prompt lives in the panel graph (T1),
and dismissal and timeout behaviour. None of that can be exercised from here: the only
trigger is a real phone sending a real file, and the loopback in
`hybrid/tools/tests/ukey2-loopback.cpp` cannot stand in, because it drives the crypto rather
than the transport. Shipping an untested modal into the notification layer is worse than the
present state, which at least fails visibly as "nothing happens".

`hybrid/tools/dead-qml.py` allowlists the file rather than deleting it, so the design survives
and the gap stays visible.

### The sweep that found it

Four MiDnight-only files were unreferenced; a fifth appeared once the first four went, because
dead code was keeping it alive. `components/images/CachingVideo.qml` was the sole user of
`services/VideoWallpaperPlayer.qml`, and both were already dead in MiDnight.

Removed: `CachingVideo.qml` (superseded — `Wallpaper.qml` plus `WallpaperPauser.qml` own that
behaviour now), `VideoWallpaperPlayer.qml` (its orphan), `BadAppleController.qml` (superseded
by `BadApplePlayer`), `TestComponent.qml` (27 lines of scaffolding that pops a red window).

Kept: `components/misc/Ref.qml`, which is unused in **all three** upstreams including upstream
itself, since the C++ `ServiceRef` replaced it. That one is upstream's to delete; removing it
here trades eight dead lines for a delete/modify conflict on every merge that touches it.

---

## T28 — Fifteen config keys accept a value and do nothing

**Symptom:** you set something in `shell.json`, the shell accepts it without complaint, and
nothing changes. There is no warning, because the key *is* in the compiled schema — it simply
has no reader.

The schema declares 349 keys. Fifteen are read by nothing, in QML or C++:

| keys | class | what happened |
|---|---|---|
| `videoWallpaperPauseOnFullscreen`, `...OnTiled`, `...OnAllDisplays`, `videoWallpaperSoundEnabled`, `videoWallpaperMuteOnMedia` | `BackgroundConfig` | **superseded, and provably so.** Their only reader was `components/images/CachingVideo.qml`, itself never instantiated. `services/WallpaperPauser.qml` replaced them with `manualPause`, `pauseOnBattery`, `pauseOnWindowOverlap` and `hwDecoder`, persisted through QtCore `Settings` rather than `shell.json`. |
| `activeOllamaModel`, `activeProvider`, `defaultProvider`, `ollamaModel`, `orionModel`, `saveChatHistory`, `snapToDefaultOllama` | `AiConfig` | the feature exists (`modules/sidebar/AiAssistant.qml`), so these may be half-wired rather than debris. |
| `screenCounts` | `ShimejiConfig` | unknown |
| `tabIndicatorHeight` | `DashboardTokens` | unknown |
| `wsIcons` | `BarWorkspaces` | unknown |

**Not removed, deliberately.** Deleting a key is user-visible: an existing `shell.json`
containing it starts emitting `Unknown option`, and the smoke matrix treats that as a
failure. That is the right outcome for a key that is genuinely gone, and the wrong one for a
key someone is halfway through wiring. The `videoWallpaper` five have an airtight story; the
`AiConfig` seven do not, and guessing at another person's unfinished feature is how you
delete groundwork.

Recorded here so the next person touching video wallpaper or the AI assistant starts from
evidence instead of rediscovering it.

### How to re-run the sweep

Extract every `CONFIG_*PROPERTY(type, name, …)` from `plugin/src/Caelestia/Config/*.hpp`, then
look for `.name` or `"name"` in the QML and for the bare name in C++ **excluding the
declaration lines themselves**. Three things it must handle, each of which produced a false
positive first time:

- **C++ consumers.** A QML-only sweep called `logout`, `shutdown`, `italic`, `vaxes`,
  `lyricsBackend` and `configLoaded` dead; all six are read from C++.
- **Dynamic access.** `modules/background/Wallpaper.qml` reads
  `Config.background["wallpaperRecolor"]`. String-literal subscripts are caught by the
  `"name"` check; a computed one would not be, and there are none today.
- **The declaration itself.** Searching C++ for the bare name matches the `CONFIG_PROPERTY`
  line, so every key looks live unless those lines are excluded.

---

## T29 — Upstream's CI image is private, so inherited CI cannot run on any fork

**Symptom:** every containerised job fails in about 25 seconds, before running a single
step of your code, with:

```
docker pull ghcr.io/caelestia-dots/shell-arch-env:latest
Error response from daemon: denied
##[error]Docker pull failed with exit code 1
```

Six of the eight jobs use `container: image: ghcr.io/caelestia-dots/shell-arch-env:latest`.
That package is private to the `caelestia-dots` org — an anonymous manifest fetch returns
**401** and GHCR refuses to issue a pull token at all. Upstream's own runners can pull it
because their `GITHUB_TOKEN` belongs to the owning org. A fork's cannot, and no amount of
`packages: read` on the fork's token changes that.

So the CI this project inherited was never going to run here. It looked configured, the
workflow files were all present and valid, and it failed at `Initialize containers` every
time.

**The fix is to own the image.** `update-image.yml` carries the entire Dockerfile inline and
pushes to `ghcr.io/${{ github.repository_owner }}/shell-arch-env:latest`, so enabling it in a
fork publishes to that fork's namespace. It shipped as `.disabled`; it is now enabled, and
the six container jobs point at `${{ github.repository_owner }}` rather than a hardcoded
name, so this works for the next fork too without edits.

**Two packages had to be added**, and they matter beyond the plumbing: upstream's image has
neither `protobuf` nor `lm_sensors`, because upstream's tree has no QuickShare. `protobuf`
is needed for the six generated `.pb.cc`, and `lm_sensors` provides the `libsensors` that
`plugin/cmake/sensorslib.cmake` resolves `Sensors::Sensors` to. **Upstream's image could
never have built this tree even if it were public** — which is worth knowing before
concluding that a green upstream CI says anything about this fork.

The job also needs `credentials:` on the container. A fork's `GITHUB_TOKEN` can read its own
owner's packages, but only if the workflow hands it to the docker login.

### The image reference must be a lowercase literal

`${{ github.repository_owner }}` preserves case — it is `YoavR1`, not `yoavr1` — and Docker
rejects an uppercase registry reference outright:

```
ERROR: failed to build: invalid tag "ghcr.io/YoavR1/shell-arch-env:latest":
repository name must be lowercase
```

The two sides have to be fixed differently, which is easy to get wrong:

- **The build tag** can be lowercased at run time, because a step runs before it is used:
  `echo "IMAGE_OWNER=${GITHUB_REPOSITORY_OWNER,,}" >> "$GITHUB_ENV"`.
- **`container: image:` cannot.** It is resolved before any step in the job exists, and
  GitHub's expression language has no `toLower()`. It must be a literal.

So the six container jobs carry `ghcr.io/yoavr1/shell-arch-env:latest` spelled out, and a
fork edits exactly that one string. The first attempt used the expression in both places on
the assumption that it was portable; it is portable only where a step can preprocess it.

---

## T30 — Three of my own checkers reported a clean tree from an empty file list

**Symptom:** in CI, and only in CI:

```
dead-signals.py     209 signal(s) checked, 0 with no reachable emitter
shell-safety.py       0 shell invocation(s), 0 allowlisted, 0 building the script from a value
dead-qml.py           0 QML file(s), 0 allowlisted, 0 unreferenced
check-index-modes.sh  index modes ok
```

Two of those numbers are zero because there was nothing to check, and all three passed.

The container runs as root while the checkout is owned by another uid, so git refuses
everything with `detected dubious ownership`, `git ls-files` prints nothing and exits 128 —
and a checker that iterates that output finds no files, reports no problems, and exits 0.
`dead-signals.py` was unaffected only because it walks the filesystem with `rglob` instead.

This is the exact defect these tools exist to find (T23), sitting in the tools. It cannot be
caught by running them locally, where git always works.

**Both halves are fixed, and both are needed.**

*The checkers* now treat a failed or empty listing as an error. `tracked_files()` in the two
Python tools and the `git ls-files -s` guard in the shell one exit non-zero with the git
error and the `safe.directory` hint. Verified with a stub `git` that fails on `ls-files`:
exit 2, 1 and 1, with a real git unchanged at 0.

*The workflows* add `git config --global --add safe.directory "$GITHUB_WORKSPACE"` before the
checkers, so the underlying problem is gone rather than merely detected.

**Testing the guard took two attempts, which is its own lesson.** The first stub failed only
when `$1` was `ls-files`. The Python tools invoke `git -C <root> ls-files …`, so `$1` is `-C`,
the stub fell through to the real git, and the tools passed — making a working guard look
broken. When a probe says a fix did not work, check the probe before the fix.

**The general rule: zero inputs is a broken checker, never a clean tree.** Any tool that
reports "N problems in M files" must refuse to report success when M is zero.

---

## T31 — Two more ways upstream's CI cannot validate this tree

Both surfaced on the first CI run that got far enough to execute real work, and both have
the same shape as T29: upstream's pipeline is correct *for upstream's tree*.

### clang-tidy needs a build first, because protoc has not run

```
plugin/src/.../QuickShareConnection.hpp:7:10: error: 'wire_format.pb.h' file not found
plugin/src/.../QuickShareCrypto.cpp:26:10: error: 'securemessage.pb.h' file not found
```

`lint-cpp` configures and then runs `run-clang-tidy` directly. A bare configure has not run
protoc, so none of the six generated `.pb.h` exist, every QuickShare translation unit fails
to parse, and clang-tidy then emits a cascade of **spurious** findings on the wreckage —
`method can be made static`, `pointee can be declared const` — none of which reproduce
locally. Upstream's job has no build step because upstream's tree has no protobuf.

`hybrid/tools/verify.sh` already built before linting for exactly this reason; the workflow
now does the same. The lesson generalises: when clang-tidy reports findings that a local run
does not, check whether the translation unit parsed at all before believing any of them.

### sway carries a file capability the container cannot grant

```
/usr/sbin/sway cap_sys_nice=ep
/usr/sbin/sway: Operation not permitted        (exit 126)
setsid: failed to execute sway: Operation not permitted
```

Arch's sway ships with `cap_sys_nice=ep`. Docker's default capability bounding set has no
`CAP_SYS_NICE`, and `execve` of a binary carrying an **effective** file capability outside
the bounding set fails with `EPERM` — so the failure happens before sway executes a single
instruction, and the message comes from `setsid` rather than from sway.

That last detail is what made it hard to read: `setsid: failed to execute sway` looks like a
problem with the harness's launch line. It is not. `setcap -r` on the binary after install
fixes it — sway wants `CAP_SYS_NICE` only for realtime scheduling, which a headless boot gate
does not need, and dropping it works regardless of how the runner is configured, unlike
`--cap-add`.

**Diagnosing this took one probe step and no guesses.** `getcap` plus `sway --version` in the
job printed the capability and the exit code, which is the entire answer. When an error is an
`execve` failure rather than program output, print what you are about to execute.

---

## T32 — The CI container is a harsher environment than a nested compositor, and it found a real bug

The first smoke run that actually reached the matrix on headless sway failed all six
presets. Almost all of it was environment: no session bus, no system bus, no logind session,
and none of `ddcutil`, `nmcli` or `hyprctl`. `smoke-ignore-headless.txt` exists for exactly
this and is only read under `--compositor sway`, so those entries cost nothing on a real
desktop, where every one of them is a genuine signal.

One line was not environment:

```
WARN scene: @utils/SysInfo.qml[22:-1]: TypeError: Cannot call method 'split' of null
```

```qml
readonly property string shell: Quickshell.env("SHELL").split("/").pop()
```

`$SHELL` is unset in a container, and `Quickshell.env` returns null rather than an empty
string, so `.split()` throws. This is **not** a CI-only defect: a systemd service, a display
manager session, or any process without a login shell hits it identically. The line directly
above it already guards the same risk with `||`, which is what makes it a slip rather than a
design choice.

Guarded with `?.split("/").pop() ?? ""`. A sweep for the same shape — a method called
straight on `Quickshell.env(...)` — found no other instance.

**Why this is worth its own entry.** The nested-Hyprland matrix on a workstation cannot find
this class of bug, because a workstation has `$SHELL`, a session bus and the hardware tools.
Anything that reads the environment and assumes it is populated will pass there and fail in
a container, a VM, or a minimal session — which is where users of a shell actually run into
it. The CI leg is narrower in what it exercises and *wider* in what it can expose.

The ignore entries were checked against the real log lines rather than written from memory,
and the check included confirming that the `SysInfo` TypeError is still reported — an ignore
list that swallowed it would have hidden the only real finding in the run.

---

## T33 — `forActive()` returns null by contract, and all 23 callers dereferenced it

`services/ShellState.qml` is explicit about it:

```qml
function forActive(): ScreenState {
    const mon = Hypr.focusedMonitor;
    for (const s of states.instances)
        if (Hypr.monitorFor(s.modelData) === mon)
            return s;
    return null;                     // <-- documented, and reachable
}
```

`Visibilities.getForActive()` forwards it unchanged. A sweep of every call site found
**23 of 23 dereferencing the result without a check**, across `modules/Shortcuts.qml` (20),
`OsIcon.qml`, `NotificationsStatus.qml` and `Toggles.qml`.

Two of them surfaced in CI on headless sway:

```
WARN scene: @modules/Shortcuts.qml[243:-1]: TypeError: Value is null and could not be converted to an object
WARN scene: @modules/Shortcuts.qml[274:-1]: TypeError: Value is null and could not be converted to an object
```

Only two, because only those two paths happen to be driven by the IPC pass. The other 21 are
the same bug waiting for a different keybind.

**Why this was not put in the ignore list.** The headless list legitimately carries
Hyprland-absence entries — `Unable to connect to Hyprland socket` and friends — and this
failure is downstream of exactly that, so hiding it would have been consistent-looking. It is
still an unguarded null dereference, which is a defect on any compositor: `focusedMonitor`
is also null during startup before a monitor is focused, and across monitor hotplug. The sway
run did not create the bug, it exercised it.

All 23 now guard, in the style the handlers already used for `root.hasFullscreen`, with the
return each function actually needs — `""` for `list()`, `"unknown"` for `isOpen()`, bare
`return` for the rest.

**The general point.** A function whose body contains `return null` has that in its contract,
and a sweep for callers is worth doing the moment you see one. Finding the first instance by
accident says nothing about how many there are: here the ratio was 2 observed to 23 present.

### The guards then revealed that the sway leg was driving nothing

With the crashes gone, the next run reported something quieter and worse:

```
WARN caelestia.qml.shortcuts: Drawer "dashboard" does not exist
```

`toggle()` tested `list().split("\n").includes(drawer)` first, and the guard makes `list()`
return `""` when there is no active screen — so no drawer name is ever in that list and every
toggle reported the wrong reason. The message blamed the drawer for the absence of a screen.

Which exposed the real problem: `forActive()` returned null for the **entire** sway run, so
the IPC drive had been a no-op there all along. Six presets booted and nothing was toggled.
That is a gate that looks like coverage and is not — the same shape as T23, arrived at from a
different direction.

Two changes, both narrow:

- `forActive()` and `componentsForActive()` fall back to the sole screen when there is
  exactly one. `Hypr.focusedMonitor` is null during startup, across hotplug, and for any run
  under another compositor; with one screen there is still only one answer to "the active
  screen". With several screens and nothing focused there is no honest answer, so null stands
  and the callers' guards still matter.
- `toggle()` checks for the screen, then the drawer, in that order, so the warning names the
  thing that is actually wrong.

The lesson worth keeping: **fixing a crash can turn a loud failure into a quiet one.** The
TypeErrors were at least visible. Had the guards been added without reading what replaced
them, the sway leg would have gone green while testing less than before.

### And once it was really driving, a third bug appeared

```
WARN scene: @modules/sidebar/News.qml[35:-1]: Error: Invalid write to global property "isFetching"
```

```qml
xhr.onreadystatechange = function () {
    ...
    isFetching = false;          // writes a *global*, not the component's property
};
```

A plain `function ()` has its own scope, so the component's properties are not visible inside
it and QML rejects the assignment at runtime. The assignments in `fetchNews`'s own body a few
lines above are fine — a QML function body does resolve against the component — which is what
makes the two look identical and behave differently. Qualified with `root.`; a sweep for bare
assignments inside `= function (…) {` callbacks found no other instance.

This one had never run before: the news fetch only happens when the sidebar opens, and the
sidebar only opened once `forActive()` stopped returning null.

**That is the shape of every round of this.** Each fix peeled back a layer of environment
noise or a crash, and something real was underneath it: `$SHELL` unset, then 23 unguarded
null dereferences, then a drive that was silently doing nothing, then a QML scope error, then
two more once the drive was actually opening panels. None of them are reachable from the
nested-Hyprland matrix on a workstation.

### The last two, both about things that are only sometimes there

```
@modules/sidebar/News.qml[41:-1]:      TypeError: Value is null and could not be converted to an object
@modules/areapicker/Picker.qml[42:-1]: TypeError: Cannot read property 'name' of undefined
```

*News* — `root` itself was null. The XHR outlives the component: the drive opens the sidebar,
the fetch starts, the drive closes it, the `Item` is destroyed, and the reply lands in a dead
closure. A real race anywhere, needing only that the sidebar be closed inside the request
window — which the drive does deterministically and a person rarely would.

**And the first fix for it was wrong**, which is the more useful half of this entry. Guarding
with `if (!root) return;` looks sufficient and is not: an object part way through teardown is
still **truthy** while its methods have already gone, so the guard passes and the call fails
one line later.

```
TypeError: Property 'parseNews' ... is not a function
QQmlVMEMetaObject: Internal error - attempted to evaluate a function in an invalid context
```

That reached CI and failed 1 of 6 presets — intermittent, because it depends on where in
teardown the reply lands. The guard was asking whether the object *exists*; the question is
whether it is still *usable*.

Testing the corpse is the wrong shape regardless. `Component.onDestruction` now aborts the
request, so the callback cannot reach a dead component at all, and the callback checks
`root.pendingRequest !== xhr` — which asks the real question ("is this still the request the
live component is waiting for") and incidentally handles a superseded request too, which
neither earlier version did.

*Picker* — `mon.lastIpcObject.specialWorkspace` was assumed present. The binding already
guarded `!mon`, which is the easy half: a monitor object can exist with an **empty**
`lastIpcObject`, during startup before the first IPC reply and for an entire run under a
compositor that is not Hyprland. Guarding the container and not its contents is a recurring
shape here, and it is worth checking for whenever a guard already exists — the presence of
one makes the missing one look handled.

Both fixed with optional chaining and an early return, and both verified 12/12 locally under
Hyprland, where neither condition arises.

---

## T34 — A fork's build reported upstream's version and upstream's commit

`caelestia --version` on a build of this tree printed:

```
Version: 2.4.0
Git revision: 750e67d93ac12b264cb8cbc3a1f2b8f429c923c2
```

That revision is `caelestia-dots/shell`'s HEAD. It is not in this repository at all — it is
the string a user would paste into a bug report, naming code they are not running.

The cause is one line near the top of `CMakeLists.txt`:

```cmake
set(REMOTE_REPO_URL "https://github.com/caelestia-dots/shell.git")
```

`VERSION` came from `git ls-remote --tags` against that URL and `GIT_REVISION` from
`git ls-remote HEAD` against it. Correct for upstream, wrong for every fork, and it also
made a plain `cmake -B build` require network access.

Both now prefer the local checkout — `git describe --tags --abbrev=0` and `git rev-parse
HEAD` — and fall back to the remote query only when there is no `.git`, which is the case
that path was really for: a source tarball. Offline configures work as a side effect.

The version *number* happens to be unchanged at 2.4.0, because Phase 2 merged upstream's
tags along with its commits, so the nearest local tag is upstream's newest. Only the
revision moved — which is the half that identifies the build.

**What this cost me, and the lesson.** Four places in this repository — `crypto-test.sh`,
`plugin-test.sh`, `verify.sh` and the README — carried a note saying "VERSION and
GIT_REVISION are parsed from *remote* tags, and this repo has no remote yet, so a bare
configure is a FATAL_ERROR". I wrote that from reading the word "remote" in the CMake and
never ran the bare configure to check. It was wrong twice over: the remote is upstream's
hardcoded URL rather than this repo's, so having no `origin` was never the issue, and a bare
configure had always worked whenever the network was up. Passing `-DVERSION= -DGIT_REVISION=`
was still harmless and is what CI does, so nothing failed — the explanation was simply
fiction, repeated four times, and it took a passing test to expose it.

**Reading code tells you what it says. Only running it tells you what it does.**

---

## T35 — `git push origin <branch>` succeeds while pushing nothing

**Symptom:** every push reports success, the working tree is clean, and the commits are not
on the remote.

After PR #1 was merged I checked out `main` and kept working. The push command in my hands
still said:

```
git push -q origin phase3/feature-flags
```

`phase3/feature-flags` had not moved, so that is a valid, successful, **empty** push. Two
commits' worth of asset work sat unpushed while three consecutive pushes reported success,
and — worse — CI never ran on them. `gh pr checks 1` kept returning green for the *merged*
PR, so the staleness looked like confirmation.

Three things conspired, and each is worth recognising on its own:

- **A no-op push is not an error.** There is nothing for git to complain about.
- **`-q` hides the one line that would have shown it.** Without `-q`, a real push prints
  `9f9b6db0..e702406a  main -> main`; an empty one prints `Everything up-to-date`.
- **The status query was pinned to a merged PR.** Checks on a merged PR never change again,
  so it answers with history and looks like an answer about now.

**What to do instead.** Push the branch you are on — `git push origin HEAD` — or check
`git status -sb`, which prints `## main...origin/main [ahead 2]`. The local backup was
unaffected because `git push backup --all` pushes every branch, which is why the work was
never actually at risk.

The general shape is the one this file keeps returning to: *a command that reports success
for doing nothing is indistinguishable from one that did the work.* It is the same failure
as the checkers that passed on an empty file list (T30) and the gate that could not fail
(T23), arriving this time through a shell command rather than a script.

---

## T36 — The QML gate linted an hours-old snapshot of the tree

`hybrid/tools/qml-lint.sh` needs a `.qmlls.ini` to tell `qmllint` where our types live.
Quickshell writes one as a **symlink into a VFS directory** — a *copy* of the QML tree made
at the moment the shell booted:

```
.qmlls.ini -> /run/user/1000/quickshell/vfs/31ac3acb.../.qmlls.ini
```

The script regenerated it only when it was missing:

```sh
if [ ! -s .qmlls.ini ]; then    # regenerates ONLY when missing or empty
```

A stale-but-valid link therefore survived forever, and the linter resolved types against a
snapshot of the tree as it had been hours earlier. Two consequences, in opposite directions:

- **a newly added file does not exist.** Importing `services/Hotspot.qml` produced eight
  `Unqualified access [unqualified]` warnings on `HotspotPage.qml` — against a correct file.
  Every one was noise from a snapshot taken before the import.
- **a deleted file still resolves.** The gate keeps passing code that references a type that
  is gone. This is the dangerous direction, and it is silent.

Fixed by regenerating when the snapshot no longer matches the tree. Two tests, because
neither alone is sufficient:

- **mtime** — any `.qml` newer than the link. Catches additions and edits. It must use
  `git ls-files --cached --others --exclude-standard`: plain `git ls-files` lists only
  *tracked* files, and a freshly imported `.qml` is untracked at exactly the moment it needs
  to be picked up. Keying on tracked files alone misses the one case the check exists for,
  and *appears* to work because some unrelated file is usually newer.
- **path set** — the `.qml` paths on disk versus those in the VFS. mtime is structurally
  blind to a deletion: removing a file leaves every survivor older than the link.

Verified in both directions by adding and then removing a `pragma Singleton` probe under
`services/` and checking the VFS contents each time.

## T37 — `--check` was not a flag, and a "dry run" rewrote 243 files

`hybrid/tools/qml-section-order.py` writes by default and takes `--dry-run`/`-n`. It parsed
its arguments like this:

```python
args = [a for a in sys.argv[1:] if not a.startswith("-")]
dry_run = "--dry-run" in sys.argv or "-n" in sys.argv
```

Anything beginning with `-` that was not one of those two was **silently discarded**. So
`--check` — the obvious guess, and the spelling the sibling checker's own docs use — parsed
as "no flags at all", and a run intended to *measure* a blast radius rewrote 243 of 367
files. It reported the damage in the past tense, `rewrote 243 of 367 file(s)`, which read as
the dry-run summary it was supposed to be.

Nothing was lost — the changes were cosmetic and `git checkout --` restored them — but one
file showed the rewrite was not purely whitespace: a comment moved across a blank line and
re-attached itself to the *next* member, so a note about `anchors.fill` came to sit above
`layer.enabled` and now documents the wrong thing.

Unknown flags are now a usage error (exit 2) and `--check` is a real dry-run alias. For any
tool that writes by default, an unrecognised flag must never degrade to "write everything".

## T38 — `qmlformat` on `PATH` is not the `qmlformat` the gate runs

```
$ which qmlformat && qmlformat --version
/usr/bin/qmlformat
qmlformat 1.0
$ /usr/lib/qt6/bin/qmlformat --version
qmlformat 6.11.2
```

`check-format.yml` and `hybrid/tools/verify.sh` both call the absolute Qt6 path. Typing the
bare name gets a different binary with a different idea of correct formatting, so files
formatted by hand with `qmlformat -i` come out *drifted* against the gate — which is how
three freshly formatted files failed the format check immediately after being formatted.
Always use `/usr/lib/qt6/bin/qmlformat`, as the scripts do.

## T39 — Fixing a rule the sibling checker already fixes

Chasing T36 I started teaching `qml-section-order.py` to insert the blank line that
`missing-section-separator` wants. Two things were wrong with that, and both are worth
remembering before extending either tool.

First, `scripts/qml-lint-conventions.py` **already has** `fix_section_separators()` and a
`--fix` mode. Our tool exists for exactly one reason: `section-order` is the rule upstream's
checker reports but cannot fix. Anything else it "fixes" is duplicated logic that can drift.

Second, it *did* drift, immediately. Reusing the tool's existing `join()` — whose blank-line
rule is the stricter aesthetic one, blanking around any multiline member even inside a
single section — would have rewritten **243 of 367 files and 858 bodies the gate does not
object to**. A hand-written narrow version still disagreed at 12 sites, because this tool
classifies attached properties (`Layout.fillWidth: ...`) as bindings while the checker
returns `None` for them and cannot see them at all. The fixer saw a section transition where
the gate saw nothing.

Churning upstream-shaped files to satisfy a rule the gate is not enforcing buys nothing and
costs merge conflicts against three upstreams. Run `qml-lint-conventions.py --fix`.

## T40 — The presets README claimed a guarantee the matrix does not check

`hybrid/presets/README.md` said of the `all-on`/`all-off` pair:

> they prove a flag gates *instantiation* rather than visibility, because the components a
> preset turns off report zero instantiations, not zero visible pixels

Nothing measures that. `run_preset()` in `smoke-matrix.sh` asserts exactly three things: the
shell is still alive when the timeout fires (`rc == 124`), the log carries no `ERROR` or
`WARN` surviving `filter_ignored`, and every IPC call driven by `drive_shell` answers. There
is no instantiation count anywhere in the harness, and no component reports one.

So `all-off` proves a disabled feature does not *break* or *warn*. A feature gated with
`visible: false` — precisely the mistake the rule exists to prevent — passes `all-off` and
`all-on` both.

The claim is now corrected in place rather than deleted, because the underlying rule is
still right; it is enforced by review (the `feature-import` skill, the `qml-reviewer` agent)
rather than by the harness. A real instantiation census is worth building.

This is the third time in this project a documented guarantee turned out to be unmeasured —
after the gate that could not fail (T23) and the checkers that passed on an empty file list
(T30). The pattern is worth stating plainly: **a sentence in a README asserting that a gate
proves something is not evidence that it does.** Read the assertion in the script.

## T41 — OP's hotspot ships one Wi-Fi password for every install, and logs it

Three findings in `services/Hotspot.qml`, all in the credential path, found while importing
it. None is as severe as the pattern lock (T3, D10) — the user has to deliberately start an
access point — but the first is a real vulnerability and the fix is a deletion.

**A published default PSK.** The service declared:

```qml
property string password: "caelestia1234"
```

`start()` passes that to `nmcli device wifi hotspot ... password <psk>`. The important part
is what the constant displaces. From `nmcli(1)`:

> password — password to use for the created hotspot. **If not provided, nmcli will generate
> a password.**

So NetworkManager's behaviour is already correct: omit the argument and every install gets
its own WPA key. OP's constant *overrides* that per-install secret with a value published in
a public GPL repository. Anyone in radio range who has read the source is on the network,
and on the LAN behind it. Fixed by making the default empty — a deletion, not a mechanism.
No RNG is needed in QML, because the one in NetworkManager was there all along.

**The generated key was logged in plaintext.** `startProc`'s stdout handler did:

```qml
console.log("[Hotspot stdout]", line);
```

and printing the password is exactly what that stdout is *for* — `nmcli -s dev wifi hotspot`
is the documented way to learn a generated one. So the WPA PSK went into the shell log and
the journal on every start. The handler is now empty.

**The generated key never reached the user.** Nothing re-read the connection after a
successful start, so with no default password the settings field would have stayed blank and
the user would have had no way to see what nmcli chose. `onExited` now calls
`readSavedConfig()` on success; `readConfigProc` already runs `nmcli -s` and populates the
field, which the page renders masked with a reveal toggle.

The general shape: **a hardcoded credential is worth checking against what the tool does
without it.** Here the "default" was not filling a gap, it was overwriting a better answer.

## T42 — Fixing the version for a bare build left every gate build reporting nothing

T34 fixed a fork that reported *upstream's* version and *upstream's* commit, by preferring
the local checkout. It did not fix the other caller. `hybrid/tools/verify.sh` and
`.github/workflows/build.yml` both configure with

```
-DVERSION= -DGIT_REVISION=
```

on purpose, so the gate never touches the network and does not depend on how the tree is
tagged. But `-DVERSION=` makes the variable **defined and empty**, and both detection blocks
in `CMakeLists.txt` are guarded by `if(NOT DEFINED VERSION)`. Defined-but-empty skips them
both, so `project(caelestia-shell VERSION ${VERSION} ...)` received no value at all:

```
CMake Warning at CMakeLists.txt:80 (project):
  VERSION keyword not followed by a value or was followed by a value that
  expanded to nothing.
```

That warning is printed on every configure in the gate and in CI, and it is not cosmetic:
`extras/version.cpp` prints `VERSION` and `GIT_REVISION` verbatim, so every gate- and
CI-built binary answered `caelestia --version` with two empty lines.

Fixed by substituting placeholders immediately before `project()` — `0.0.0` and `unknown` —
rather than by falling back to detection. Falling back would reintroduce exactly the network
dependency the empty values exist to avoid: with no tags, local detection fails through to
the remote `git ls-remote` query. A build that says `0.0.0` is honest about being an
unversioned build; one that says nothing looks broken.

Both paths are verified, because fixing one had already broken the other once:

| configure | version | revision |
|---|---|---|
| bare | `2.4.0` | the real local HEAD |
| `-DVERSION= -DGIT_REVISION=` | `0.0.0` | `unknown` |

The lesson is narrower than T34's and worth keeping separate: **a variable can be set and
still be empty, and `if(NOT DEFINED)` does not notice.** The guard has to match how callers
actually pass the value, not how you imagine they do.

## T47 — Adding an enumerator has two homes, and only one of them fails loudly

Adding `Intel` to `GpuType` touches two places, and they fail in opposite ways.

The config side is safe. Enums are serialised **by name** -- `EnumCodec::encode` writes
`m_metaEnum` keys and `decode` compares strings case-insensitively -- so an existing
`shell.json` saying `"gpuType": "nvidia"` keeps working wherever the enumerator sits, and an
unknown name is rejected with a diagnostic rather than silently mapped to whatever now
occupies that slot.

`modules/nexus/pages/ServicesPage.qml` is not:

```qml
// GPU types, ordered to match config::GpuType (Auto, Nvidia, Generic, None)
readonly property list<MenuItem> gpuItems: [ ... ]
```

That list is indexed by **ordinal**. Insert an enumerator anywhere but the end and every entry
after it labels the wrong type -- the dropdown reads "Generic" and sets `None` -- and nothing
detects it. Not the compiler, which never sees the QML; not `qmllint`, which sees a valid list
of `MenuItem`; not the smoke matrix, which boots the page fine because the list is the right
*length*. The only symptom is a settings menu that lies.

So `Intel` is appended rather than slotted next to `Nvidia` where it reads better, and the
comment in both files now says the list is ordinal-coupled and must be appended to.

The general shape: **serialising by name buys safety at the persistence layer and none at all
in a UI that indexes by position.** When a type is duplicated as a literal list somewhere, the
duplicate is the copy that will rot, and its only protection is a comment pointing at the
original.
