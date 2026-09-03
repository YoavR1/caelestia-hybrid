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
- the two `QObject: ... different thread` entries — **deleted**. They were attributed to
  QuickShare teardown, matched nothing across 12 runs, and were suppressing an entire Qt bug
  class globally rather than one known instance. The matrix stayed clean over 12 runs
  without them, so the coverage is back and cost nothing.

The distinction to draw when auditing is not "does this still fire" but "if the thing this
hides came back, would I want to know?" A pattern naming one file and one condition is a
note; a pattern naming a Qt-wide diagnostic is a policy.


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
