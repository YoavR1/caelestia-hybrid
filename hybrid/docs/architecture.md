# Architecture

Decision record for Caelestia Hybrid. Written 2026-09-02 from a source audit of all three
upstreams at the commits recorded in `CLAUDE.md`.

---

## 1. What this project is

One Quickshell desktop shell that combines the features of **MiDnight Shell** and **OP-Caelestia**
on top of upstream **Caelestia**, presented to the user as a single shell with a settings UI — not
as a launcher that picks between three shells.

From a user's perspective there is one thing to install and one thing to update. Upstream changes
are integrated by maintainers, not by users.

---

## 2. The finding that shaped the design

The original plan was a runtime *implementation registry*: every major component would exist twice
(OP and MiDnight), with a Nexus selector choosing which one instantiates, backed by shared services
and per-fork compatibility adapters.

The audit showed the forks do not overlap enough for that to pay off.

```
Files touched by OP:        133
Files touched by MiDnight:  456
Files touched by BOTH:       48
```

Component by component:

| Component | OP | MiDnight | Two implementations? |
|---|---|---|---|
| Dock | `modules/dock/`, 3 files, own Wrapper/window | `modules/bar/components/Dock.qml`, a bar component | No — different things entirely |
| Bar | 2 files, +16 lines | 19 modified, 10 new | No — only MiDnight |
| Overview | 12 files | — | No — only OP |
| Wallpaper | 1 line in `Wallpapers.qml` | 125 → 486 lines | No — only MiDnight |
| Clipboard, emoji picker, window switcher, shimeji | — | yes | No — only MiDnight |
| Hotspot, BtAgent, GPU detection, theme manager | yes | — | No — only OP |
| Lock centre | `PatternGrid`, `PowerConfirm`, `LockActions` | `Center`/`Content` redesign | **Yes** |
| Audio popout | +399/-6 | +104/-66 | **Yes** |
| Background / desktop clock | +30/-90 | +170/-5 | **Yes** |
| Colours | +52/-2 | +44/-9 | **Yes** |

**Four** genuine dual-implementation sites, not twelve. So there is no `2^12` combinatorial space —
there is a ~90% disjoint feature set plus four contested components.

That inverts the primitive: **a feature flag, not an implementation selector.**

Building a registry, host/Loader indirection, compat adapters and per-component contracts for four
sites would be infrastructure for a problem the codebase does not have.

---

## 3. The other finding: upstream is moving fast underneath both forks

In the 13 days after the fork points, upstream shipped 197 files, +6416/-5048, including:

- `refactor(config): rewrite config module (#1861)`
- `refactor: rearrange plugin layout (#1896)`
- A new `plugin/src/Caelestia/Settings/` C++ module — `schema`, `node`, `rootnode`, `objectnode`,
  `listnode`, `settingsfile`, `codecs`, `changebatcher`, `quarantine`, and **`layerregistry.hpp`**
- `feat(services): migrate NetworkUsage from QML to C++ (#1860)` — which both forks wrote in QML
- A mass style sweep (scoped enums, `u""_s`, include ordering, clang-tidy)

Both forks still carry the **old** plugin layout (`Internal/`, `appdb`, `imageanalyser`).

Two consequences:

1. `LayerRegistry` is a config layering system with fallback chains
   (`ConfigRoot(path, fallback, parent)`, `forScreen(name)`). It obsoletes MiDnight's own
   per-monitor config work, and it is exactly the mechanism presets should be built on.
2. Deferring the upstream catch-up makes it strictly worse. It is Phase 2 for that reason.

---

## 4. Decisions

### D1 — Baseline is MiDnight

Porting OP into MiDnight moves ~8.9k lines that are unusually well-isolated: `modules/dock/` (3
files), `modules/overview/` (12), `services/{Hotspot,BtAgent,Nmcli}.qml`,
`plugin/src/Caelestia/Services/gpu.{cpp,hpp}`, the theme manager, ~10 Nexus pages, and theme assets.
Estimate: 2-3 weeks.

Porting MiDnight into OP moves 33.5k lines across 456 files including 54 C++ files. Months.

The original reason to prefer OP — "it already has Nexus" — does not hold: `modules/nexus/` is
upstream (66 files upstream, 77 OP, 96 MiDnight). MiDnight extended it further than OP did.

**Cost accepted:** MiDnight's maintenance debt — disabled CI (T9), unlinted code, and per-monitor
config that upstream has superseded (T7). Phase 0 exists to pay this down immediately.

**Alternative considered and rejected:** baseline on upstream `main` and re-land both forks cleanly.
Architecturally purest, but 33.5k lines of re-landing, and MiDnight's author already merges upstream
periodically — we would be permanently duplicating their work.

### D3 — Feature flags, with a capped variant list

```jsonc
{
  "hybrid": {
    "preset": "recommended",
    "features": {
      "dock": true, "overview": true, "hotspot": true,
      "clipboard": true, "emojiPicker": true, "shimeji": false,
      "videoWallpaper": true, "wallhaven": true, "badApple": false
    },
    "variants": {
      "lockCentre": "midnight",
      "audioPopout": "op",
      "desktopClock": "midnight"
    }
  }
}
```

`features` is the workhorse — one boolean per imported feature. `variants` covers only the four
genuine overlaps and is capped at ~6 entries (D4). Growth past that means the design is drifting back
toward the rejected registry.

Implement `variants` with Loader hosts **only** where the component is weakly referenced —
`lockCentre` and `audioPopout` are leaves and qualify. Anything inside the Panels/Interactions graph
(T1, T2) gets merged into one implementation with config properties instead.

### D5 — Services merge, never dual-implement

The forks extended a shared service set rather than forking it. Only `Audio.qml`, `Colours.qml` and
`Wallpapers.qml` are touched by both, and the Audio conflict resolves by keeping both sides (T8).
Every other service addition is disjoint.

The feared outcome — two PipeWire services, two Hyprland services — cannot happen here, and T5
explains why shadowing a singleton would not achieve it anyway.

### D6 — One CLI

`dim-ghub/midnight-cli` and `dim-ghub/caelestia-cli` are the same repository at the same commit: a
fork of `caelestia-dots/cli`, 18 files, +849/-88. It installs its binary as **`caelestia`**, and every
QML call site in all three shells is `["caelestia", ...]`.

You therefore cannot install both. Fork `caelestia-dots/cli`, apply MiDnight's delta (video wallpaper
and `--extract-thumbs`, extended `screenshot`, `record --fps`, `search`, astra scheme), ship as
`caelestia-hybrid-cli` providing `/usr/bin/caelestia`. Upstream the genuinely general parts.

### D8 — Presets are config layers, and config stores the preset name

Upstream's `LayerRegistry` already provides fallback chains. A preset becomes a layer *beneath* the
user's layer: explicit user settings win, unset keys fall through to the preset.

Storing the preset *name* rather than its expanded values means "Recommended Hybrid" can be improved
later and existing users receive the improvement. It also makes migration free — an existing
`shell.json` with no `hybrid` block is just a user layer, and defaults apply. Nothing corrupts.

Until Phase 2 lands, ship `hybrid/presets/*.json` merged under user config at load.

Four presets: `op`, `midnight`, `recommended`, and "custom" — which is not a stored value but the
computed state when a user overrides any key.

### D9 — Merge upstream, cherry-pick OP

- Upstream is a true ancestor: `git merge caelestia/main`. Never rebase.
- OP shares ancestor `ad8dca0a` with our line, so `git cherry-pick -x` works directly on its 49
  commits. No patch files, no subtree, no submodules.
- `git rerere` is enabled by `bootstrap.sh` — the same conflicts recur across repeated merges, and
  this is the single highest-value setting for the project.
- One sync branch per upstream (`sync/op/YYYY-MM-DD`), never a combined sync.

**Rejected: subtree** (imports upstream's whole tree, including files we deleted) and **submodules**
(cannot express "our file is upstream's file plus edits").

**Rejected: `upstreams.lock.json`.** Merge commits and `cherry-pick -x` already record integration
points; a hand-maintained ledger drifts. `hybrid/tools/upstream-status.sh` derives the same report
from git on demand.

For monitoring: a scheduled workflow comparing pinned vs. upstream HEAD that opens an **issue** —
never a PR, never an automatic merge into `main`.

---

## 5. Testing

> **Corrected 2026-09-02, on first contact with a real Linux target.** This section previously
> claimed upstream's `lint.yml` already contained a headless smoke test:
> ```bash
> QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="…" timeout 2 qs -p .
> ```
> It does not. That line sits under a `# Generate tooling` comment, exists to emit `.qmlls.ini`
> for the linter, and **its exit code is never checked**. Run against this shell it fails
> immediately with `No PanelWindow backend loaded`, because Quickshell's `PanelWindow` is a
> wlr-layer-shell surface and `offscreen` provides no Wayland backend. The failure poisons the
> whole singleton graph (trap T12).

The gate therefore needs a real compositor. `hybrid/tools/smoke-matrix.sh` spawns a **nested
Hyprland** on its own socket, then for each preset boots the shell against it under an isolated
`XDG_CONFIG_HOME` and fails on QML errors. It refuses to run against the live session socket, so
it can never draw over a working desktop, and a cleanup trap tears the compositor down.

Measured cost: ~3s compositor startup, then one window per preset. Three presets at a 12s window
is well under a minute.

**Open item for CI:** a GitHub Actions container has neither a parent Wayland display nor a free
DRM device, so nested Hyprland cannot start there. Either the runner needs a headless
wlroots compositor (`cage`, `sway --headless`) or a virtual DRM device (`vkms`). Resolve this
before wiring `smoke-matrix.sh` into CI; it works locally today.

Because each run costs seconds, arbitrary combinations are affordable — all presets plus a dozen
randomised `features`/`variants` combos per CI run, including deliberately hostile ones (all on, all
off, every variant flipped). That plus `qmllint` covers essentially every failure class a
contract/registry abstraction would have been protecting against.

**Build this before the feature system**, so the feature system lands with coverage. That is Phase 1.

Inherit upstream's `lint.yml`, `check-format.yml`, `build.yml` and `check-pr-title.yml` unchanged
except the container image.

---

## 6. Roadmap

```
Phase 0   Fork MiDnight. Re-enable check-format + lint CI. Fix the backlog.        ~1 wk
Phase 1   Offscreen smoke-test harness + preset matrix runner in CI.               ~1 wk
Phase 2   Merge upstream/main: config rewrite, plugin rearrange, style sweep.     2-4 wks
          Drop MiDnight per-monitor config in favour of LayerRegistry.
Phase 3   hybrid.features flag system + 4 presets + Nexus preset page.             ~1 wk
Phase 4   Import OP's dock behind hybrid.features.dock.    <- PROOF OF CONCEPT
Phase 5   Import OP overview, hotspot/BtAgent/Nmcli, GPU detection, themes.       3-4 wks
Phase 6   Single merged CLI.                                                       ~1 wk
Phase 7   The four real variants. Merge where possible; Loader-host only
          lockCentre and audioPopout.
Phase 8   Security: rework or drop OP's pattern lock. Blocks any release
          shipping pattern auth.
```

Phase 2 precedes Phase 3 deliberately: presets are built on the config system we keep, not the one
upstream just deleted.

### Why the dock is the proof-of-concept

Not because it proves dual-implementation — it cannot, since MiDnight has no dock module. It is the
right first slice because it proves the things that actually carry risk:

- cross-fork import works end to end, with provenance
- the feature-flag system gates a real module
- the Panels / Interactions / Regions coupling (T1, T2) is survivable
- the smoke harness catches breakage
- it is visually obvious when it works, and it is not authentication

If this slice takes more than ~3 weeks, that is the signal to reconsider scope before committing
further.

---

## 7. Explicitly not doing

- A runtime implementation registry with per-component selectors (§2).
- A `variants/midnight/` parallel source tree — T5 shows singleton shadowing does not work, and D5
  removes the need.
- Per-fork compatibility adapters over shared services — the services are already shared.
- Sub-component mixing inside wallpaper (T6) or lockscreen auth (T3).
- Swapping the bar (T2).
- Two CLIs, or an adapter layer over two CLIs (D6).
- Automatic merges of upstream into `main`.
- Shipping OP's pattern lock unmodified (T3).
