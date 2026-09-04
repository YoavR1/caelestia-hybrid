---
name: feature-import
description: >-
  Import a feature from OP-Caelestia or MiDnight into the hybrid shell behind a feature flag,
  with provenance and verification. Use when asked to port, bring over, add, or import any
  feature from either fork — dock, overview, hotspot, GPU detection, theme manager, clipboard,
  emoji picker, window switcher, wallpaper features, shimeji, and so on. This is the repeated
  unit of work for Phases 4 through 7.
---

# Importing a feature from a fork

The repeated unit of work. Roughly 15-20 of these across Phases 4-7. Do them one per branch,
one per PR.

## 0. Decide it is actually an import

Before starting, check three things:

1. **Does upstream already have it?** Look in `$CAELESTIA_REFS/upstream` first. Upstream absorbed
   `NetworkUsage` into C++ and built config layering that supersedes MiDnight's per-monitor work
   (T7). Importing something upstream has since implemented is pure debt.
2. **Do both forks have it?** If so, the default is **one merged implementation with config
   options**, not two implementations (D3, D5). A `hybrid.variants` entry is reserved for the four
   known dual sites — lock centre, audio popout, background/desktop clock, colours (D4).
3. **Is it a service?** Services merge, never dual-implement (D5). Fork service diffs are additive
   and non-overlapping; see T8 for the resolution pattern.

Use the `fork-archaeologist` agent to answer "where does this live and what does it touch" before
writing anything.

## 1. Scope the import

```bash
REFS=${CAELESTIA_REFS:-../caelestia-refs}
SRC=op          # or midnight

# What files does the feature span?
git diff --name-status $(git merge-base $SRC/main caelestia/main) $SRC/main | grep -i <feature>

# What does it pull in?
grep -rn "import \|GlobalConfig\." <files> | sort -u
```

Write the file list down. An import that grows past its list mid-way is a signal you missed a
dependency — stop and rescope rather than following it.

**Watch for:** new config properties (needs the `config-property` skill), new Nexus pages
(`PageRegistry.qml` + `PageCompRegistry.qml`), new C++ in `plugin/src/`, new assets, and edits to
`modules/drawers/` (T1, T2) or shared services (T5).

## 2. Bring the code across

Prefer cherry-pick — it records the source commit automatically:

```bash
git switch -c import/<feature>
git cherry-pick -x <sha>            # OP shares ancestor ad8dca0a, so this works directly
```

Copy only when the source commit is entangled with unrelated work:

```bash
git checkout $SRC/main -- <paths>
```

Then fix imports for our tree. Keep the imported code **as close to its upstream form as
practical** — future syncs get cheaper. Reformat only what the formatter forces.

## 3. Put it behind a feature flag

Every imported feature is gated by `hybrid.features.<name>` (D3). Add the property with the
`config-property` skill.

Gate so the disabled implementation **does not instantiate** — `Loader { active: ... }` or
`Variants { model: ... }`, never `visible: false`. Lazy singletons mean an unreferenced service
costs nothing (T5), but an instantiated-and-hidden panel costs everything.

If the feature adds a panel inside `modules/drawers/Panels.qml`, re-read T1 before touching the
alias/anchor graph.

## 4. Record provenance

Add a row to `hybrid/docs/provenance.md` **in the same commit**:

| Feature | Source | Source commit | Original path | Local path | Kind | Notes |

`kind` is `copied`, `adapted`, or `reimplemented`. An `adapted` row needs a real one-line reason.

Binary assets get rows too — and check `hybrid/docs/provenance.md`'s asset watchlist. GPL-3.0
covers the code; it does not launder bundled third-party artwork.

## 5. Put the flag in the presets

Add the flag to the three preset tables in `plugin/src/Caelestia/Config/hybridconfig.cpp` --
those are the source of truth for what a preset *means* -- and to the three `hybrid/presets/*.json`
files that set flags explicitly (`all-on`, `all-off`, `variants-flipped`). The other three name a
preset and nothing else, so they need no edit. Keep `hybrid/presets/README.md`'s feature count in
step.

**Do not add a preset per feature.** The six in `hybrid/presets/` each have a distinct job (see the
table in its README) and the matrix runs every one against two compositor configs, so a file per
feature multiplies the gate's runtime for very little: `all-off` already proves the feature does not
instantiate and `all-on` proves it does. Add a preset here only for a *combination* that is
interesting on its own -- something deliberately hostile, or two features that interact.

## 6. Verify

Run the full gate from the `shell-verify` skill. Then, specifically for imports:

- boot with the feature **off** and confirm nothing from it appears in the log
- boot with it **on** and confirm it initialises
- if it touches `modules/drawers/`, exercise hover/drag on a real session via `dev-shell.sh`

## 7. Commit

One feature per PR. Message shape:

```
feat(<area>): import <feature> from <op|midnight>

Source: <repo>@<sha>
Flag:   hybrid.features.<name>
Kind:   copied | adapted | reimplemented

<what changed relative to the source, and why>
```

## Known import notes

| Feature | Source | Notes |
|---|---|---|
| Dock | `op` | **Not the easy import this table used to claim.** It said "own Wrapper/window, so Loader-hosting is safe"; the source says otherwise. `modules/dock/Wrapper.qml` is an `Item` driven by `screenState.dock`, and `modules/drawers/` reaches into it from three places — `Regions.qml` (`panel: root.panels.dock`, plus its context-menu height in the region calculation), `ContentWindow.qml` (`dockBg`, and `dock.transform` fed by `dockBg.deformMatrix`) and `Interactions.qml` (`dockShortcutActive`). So it is a panel in the coupling graph, and importing it means editing the one area T1 and T2 exist to warn about. It also lands beside MiDnight's bar dock, which `hybrid.features.dock` already gates — two docks, not one behind a flag. Rescope before attempting: it needs either a second flag or a fifth `hybrid.variants` entry, and that is a design decision, not a port. |
| Overview | `op` | **Do not import as a feature.** 12 files under `modules/overview/`, but MiDnight also ships `modules/drawers/WorkspaceOverview.qml` (447 lines), it is already in this tree, and `hybrid.features.overview` already gates it. This is a dual site (the fifth), so it is a `hybrid.variants` question for Phase 7, not an import. |
| Hotspot / BtAgent | `op` | `services/{Hotspot,BtAgent,Nmcli}.qml` + `scripts/bt-agent.py`. Pulls a `dnsmasq` runtime dep. |
| GPU detection | `op` | C++: `plugin/src/Caelestia/Services/gpu.{cpp,hpp}`. Upstream has since typed GPU kind as an enum — check for overlap. |
| Theme manager | `op` | Ships large binary theme assets with **unresolved licensing**. Import the code; hold the assets. |
| Pattern lock | `op` | **Blocked (T3, D10).** Security defect. Do not import without the rework. |
| Wallpaper features | `midnight` | `services/Wallpapers.qml` is 125→486 lines and the state model *is* the feature (T6). One implementation, config options. Needs the merged CLI (D6) for `--extract-thumbs`. |
| Clipboard / emoji | `midnight` | Launcher entries; needs CLI subcommands. Good plugin-entry-point shape (T11). |
| Shimeji / Bad Apple / Dino | `midnight` | Self-contained, default off. 46 + 74 + 8 asset files with **unresolved licensing**. |
