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
- CI has neither a parent display nor a free DRM device, so this will not work in a GitHub Actions
  container as-is. Needs `cage` / `sway --headless` / `vkms` there.

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

Wallpaper-engine volume/silent and the pauser's settings therefore never persist across restarts.

Adding an explicit `location:` does **not** fix it — `WallpaperPauser` already has one and still
fails. The fix is to set the app identifiers from the C++ plugin, or to port both to the project's
own config / `FileView` persistence. Suppressed in `smoke-ignore.txt` under KNOWN BUGS.

---

## T15 — MiDnight deleted `assets/wallpaper.webp` but kept the reference

Fixed 2026-09-02, recorded because it is the shape of bug to expect from the baseline.

`326d9090 "Add multiple featured wallpapers to wallpaper picker"` removed `assets/wallpaper.webp`
(present in upstream and OP, 5.5 MB) and added `assets/wallpapers/*.png`. But
`services/Wallpapers.qml:18` still pointed `fallback` at the deleted file, and `fallback` is used
in four places — including `caelestia wallpaper -f "$fallback"`, so a fresh install asked the CLI
to set a nonexistent wallpaper.

Now points at `assets/wallpapers/Gravitation.png`. Found by the very first smoke run.
