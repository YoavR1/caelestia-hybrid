---
name: caelestia-conventions
description: >-
  House rules for writing QML and C++ in the Caelestia Hybrid shell. Load this before editing
  any .qml, .hpp or .cpp file in this repository, and before adding a module, service, panel,
  bar component or Nexus page. Covers Quickshell idioms, the singleton rule, the Panels and
  Interactions coupling contracts, config macros, import paths, and the zero-tolerance lint
  requirement. Use whenever you are about to write shell code here rather than reading it.
---

# Caelestia Hybrid — code conventions

Read `hybrid/docs/traps.md` alongside this. The traps are the *why*; this is the *what*.

## Before writing anything

1. **Check whether upstream already does it.** Upstream moves fast — it recently absorbed
   `NetworkUsage` into C++ and built per-screen config layering that supersedes MiDnight's
   per-monitor work (T7). Look in `$CAELESTIA_REFS/upstream` before implementing.
2. **Check which fork already has it.** Use the `fork-archaeologist` agent rather than
   reimplementing something that exists in `$CAELESTIA_REFS/op` or `$CAELESTIA_REFS/midnight`.
3. **Prefer merging over branching.** If both forks have a version, the default is one merged
   implementation with config options — not two implementations (D3, D5).

## Ownership boundaries

| Path | Rule |
|---|---|
| `modules/` `components/` `services/` `plugin/` `shell.qml` `scripts/` `assets/` `.github/` | Upstream-shaped. Merge target. **Edit minimally**, and expect to re-resolve on every sync. |
| `hybrid/` | Ours. Upstream will never touch it. Put project-owned tooling, docs and presets here. |
| `.claude/` `CLAUDE.md` | Ours. |

Never add a project-owned file to an upstream-shaped path. It guarantees a conflict later for
zero benefit.

## QML

**Imports.** Quickshell resolves `qs.<dir>.<subdir>` from the shell root; there are no `qmldir`
files (upstream has zero). Directory imports (`import "modules/drawers"`) are used in `shell.qml`
only. Follow the surrounding file's style rather than introducing a new one.

**Singletons are lazy.** A `pragma Singleton` type is constructed on first reference.
`services/ServiceLoader.qml` exists to *force* a handful to load early. Consequences:

- Dead code costs nothing at runtime — an unreferenced service is never constructed.
- You **cannot shadow a singleton**. `qs.services.Colours` and any parallel copy are different
  types; everything importing `qs.services` gets the shared one (T5).
- Therefore: change behaviour inside the single shared service, gated by config. Do not fork it.

**Panels.** `modules/drawers/Panels.qml` is a mutual-reference graph, not a list (T1). Before
touching it:

- `readonly property alias` **cannot** point into a `Loader`. If you introduce one, ~11 aliases
  become `property Item` and ~107 `panels.<x>` call sites across 6 files need null-safety.
- `modules/drawers/Regions.qml` derives the Wayland input region from panel geometry — a null
  panel during load is a frame of wrong click-through.
- Loader-host only self-contained modules with their own window/`Wrapper`.

**The bar contract.** `modules/drawers/Interactions.qml` reads ten members off the bar
(`checkPopout`, `clampedWidth`, `closeTray`, `dragThreshold`, `handleWheel`, `implicitWidth`,
`isHovered`, `minHoverThreshold`, `popouts`, `showOnHover`). If you add a bar component, do not
change those signatures. There is one bar (T2).

**New bar components** should be shaped like upstream's planned plugin entry points —
`BarEntry`, `BarPopout`, `StatusIcon`, `QuickToggle`, `DashboardTab` — so they can migrate onto
the plugin system when it lands (T11). Do not invent a competing manifest format.

**Feature gating.** A feature behind `hybrid.features.<name>` should not instantiate when off.
Prefer a `Loader { active: ... }` or a `Variants { model: ... }` over `visible: false`, so the
disabled implementation genuinely does not run.

## C++

**Config schema is compiled**, not dynamic JSON (T10). Adding a setting is a multi-file recipe —
use the `config-property` skill rather than improvising.

**Two config systems exist.** Know which tree you are in:

- **MiDnight/OP (pre-Phase-2):** `ConfigObject` base, registered in `config.hpp`'s `GlobalConfig`
  with a matching `Q_MOC_INCLUDE`.
- **Upstream (Phase 2+):** `settings::ObjectNode` base with the `CONFIG_NODE` macro, registered in
  `rootnodes.hpp`'s `ConfigRoot`. Adds layering via `settings::LayerRegistry` and
  `ConfigRoot::forScreen()`.

Match the tree you are actually editing. Do not port one style into the other ad hoc.

**Follow upstream's current style**, which changed recently: scoped enums, `u""_s` string literals
(not `QStringLiteral`, not `QLatin1Char`), sorted includes via clang-format, cross-module headers
included via named prefixes. `clang-tidy` and `clazy` run in CI.

## Lint is zero-tolerance

Upstream's `lint.yml` fails on *any* `qmllint` output. MiDnight disabled its CI (T9); we do not.

```bash
cmake -B build -G Ninja && cmake --build build
./hybrid/tools/smoke-matrix.sh
```

See the `shell-verify` skill for the full gate. Do not call a change done before it passes, and
do not disable a check to make it pass.

## Provenance

Any file imported from an upstream gets a row in `hybrid/docs/provenance.md` **in the same
commit**. Prefer `git cherry-pick -x` over copying — it records the source commit for you.

## Security

`modules/lock/` is authentication code. Changes there get a second look, and OP's pattern lock does
not ship in its current form (T3, D10). Never introduce a credential comparison in QML, and never
call `lock.unlock()` outside a PAM success path.
