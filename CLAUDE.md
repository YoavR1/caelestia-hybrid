# Caelestia Hybrid — project constitution

A single merged Quickshell desktop shell combining **MiDnight Shell** and **OP-Caelestia**
on top of upstream **Caelestia**. One shell, one config, one CLI — features toggled, not forks juggled.

> Read `hybrid/docs/architecture.md` for the reasoning and `hybrid/docs/traps.md` before touching
> anything in `modules/drawers/`, `services/`, `modules/lock/`, or `plugin/src/`.

## Status

**Phases 0, 1 and 2 are done. Phase 3 (the feature system) is in progress.**

| branch | what |
|---|---|
| `phase0/scaffold-and-ci` | scaffold, docs, tooling, all four static gates brought to zero |
| `phase2/upstream-catchup` | 51 upstream commits merged, incl. the config-module rewrite |
| `phase3/feature-flags` | `hybrid.features` / `hybrid.variants` schema + Nexus page |

Every gate upstream enforces is green on a tree that arrived with all of them failing:

| gate | was | now |
|---|---|---|
| `qmlformat` | 92 of 372 files drift | 0 |
| `clang-format` | 23 of 143 files drift | 0 |
| `scripts/qml-lint-conventions.py` | 1034 | 0 |
| `qmllint` | ~810 | 0 |
| `clang-tidy` | 446, never run | 0 |
| `g++ -Werror` (`build.yml`) | 11, never run | 0 |
| `clazy -Werror` (`build.yml`) | 9+, never run | 0 |
| smoke matrix | did not run at all | 6 presets, x2 compositor configs |
| `hybrid/tools/plugin-test.sh` | no test of any kind existed | 2 tests, 0 failures |

CI runs every row (`.github/workflows/smoke.yml` carries the last two, on headless sway).
`hybrid/tools/qml-section-order.py` is ours — the `section-order` fixer upstream's checker
lacks. `hybrid/tools/plugin-test.sh` is ours too, and runs the only executable tests in the
tree: a full UKEY2 handshake between two `QuickShareCrypto` instances, and a check that
`BeatTracker::beat` reaches its QML receiver — it had been declared, connected to by
`MediaShapes.qml`, and emitted by nothing, in all three upstreams (T21).

Read `hybrid/docs/traps.md` T12–T23 before touching the harness; **T18 and T19 in
particular**, because qmllint silently lints against an installed `midnight-shell-git`
unless `--bare` is passed, and because the two `-Werror` build legs sat red through a phase
that reported CI green — they were never run locally, and a `clazy` finding is invisible to
`g++`.

`hybrid/docs/phase2-upstream-catchup.md` records every merge decision and the API mapping from
the old `ConfigObject` to `settings::ObjectNode`.

Still missing: `git remote add origin <your fork>`. Nothing has been pushed anywhere.

## Locked decisions

These were settled by source audit on 2026-09-02. Do not re-litigate without new evidence.

| # | Decision | Why |
|---|---|---|
| D1 | **Baseline is `dim-ghub/midnight-shell`**, not OP | MiDnight's delta is 4x OP's (33.5k vs 8.9k lines). Porting OP→MiDnight is weeks; the reverse is months. |
| D2 | **Nexus is upstream**, not an OP asset | `modules/nexus/` exists in all three. It is not a reason to prefer any baseline. |
| D3 | **Feature flags, not implementation selectors** | The forks are ~90% disjoint. Only 4 components have two real implementations. |
| D4 | **`hybrid.variants` is capped at ~6 entries** | If it grows, the design is drifting back toward a registry we deliberately rejected. |
| D5 | **Services are merged, never dual-implemented** | Both forks *extended* a shared service set. Their diffs are additive and non-overlapping. |
| D6 | **One CLI**, forked from `caelestia-dots/cli` | Both CLIs install the binary as `caelestia`; you cannot have both. MiDnight's delta is ~850 lines, additive. |
| D7 | **Upstream catch-up is Phase 2**, before the feature system | Upstream rewrote the config module and rearranged the plugin layout. Build presets on the system we keep. |
| D8 | **Presets are config layers**, and config stores the preset *name* | Lets "Recommended Hybrid" be improved later for existing users. |
| D9 | **Merge upstream; cherry-pick OP** | Upstream is a true ancestor. OP shares ancestor `ad8dca0a`, so `git cherry-pick -x` works directly. Never rebase onto an upstream. |
| D10 | **OP's pattern lock does not ship as-is** | It is a lock-screen bypass. See `hybrid/docs/traps.md`. Release blocker. |

## Hard rules

1. **Never `rm -rf` a config dir or `killall quickshell`.** OP's `install.sh` does both. Never run it here,
   and never copy its patterns. Development uses `hybrid/tools/dev-shell.sh`, which is isolated.
2. **Never rebase our branch onto an upstream.** Merge (upstream) or cherry-pick (OP).
3. **`qmllint` and `clang-format` are zero-tolerance**, as upstream has them. MiDnight disabled its CI;
   we re-enable it in Phase 0 and do not disable it again.
4. **Every imported file gets a provenance row** in `hybrid/docs/provenance.md` in the same commit.
5. **Project-owned code lives in `hybrid/`.** Never add project-owned files to `scripts/`, `modules/`,
   `services/`, or `components/` — those are upstream-shaped paths and will collide on merge.
6. **Prefer an adapter/wrapper over editing an upstream file** — but only up to the point where the
   adapter is smaller than the edit. A 200-line adapter replacing a 20-line edit is the wrong trade.
7. **All three upstreams are GPL-3.0.** Preserve license headers, authorship and history. Do not squash
   imported history in a way that erases attribution.

## Repository layout and ownership

```
modules/  components/  services/  plugin/  shell.qml   ← upstream-shaped. Merge target. Edit minimally.
scripts/  assets/  .github/                            ← upstream-shaped. Same rule.
hybrid/                                                ← ours. Upstream will never touch it.
  ├── docs/       architecture, traps, provenance ledger
  ├── presets/    op.json, midnight.json, recommended.json
  └── tools/      bootstrap, upstream-status, smoke-matrix, dev-shell
.claude/                                               ← ours (skills + agents)
```

## Reference checkouts

`bootstrap.sh` creates read-only worktrees of all three upstreams at `$CAELESTIA_REFS`
(default `../caelestia-refs/`):

```
../caelestia-refs/upstream    caelestia-dots/shell   @ caelestia/main
../caelestia-refs/op          OVERxPOWERED/…         @ op/main
../caelestia-refs/midnight    dim-ghub/midnight-shell@ midnight/main
```

Agents and skills read these. Never edit them; they are throwaway checkouts.

## Verified upstream facts (2026-09-02)

| | commits | HEAD | delta vs its fork point |
|---|---|---|---|
| `caelestia-dots/shell` | 2610 | `750e67d9` | — |
| `OVERxPOWERED/op-caelestia-shell` | 2610 | `621339cf` | fork `b1c9bbd0`, 49 commits, 133 files, +8892/−1177 |
| `dim-ghub/midnight-shell` | 3087 | `bb7b5657` | last merge `ad8dca0a`, 528 commits, 456 files, +33543/−2033 |

- Files touched by **both** forks: **48**. OP-only: 85. MiDnight-only: 408.
- `modules/nexus/`: 66 files upstream, 77 OP, 96 MiDnight.
- Upstream moved 197 files (+6416/−5048) in the 13 days after the fork points, including
  `refactor(config): rewrite config module (#1861)` and `refactor: rearrange plugin layout (#1896)`.
- Both forks still carry the **old** plugin layout (`Internal/`, `appdb`, `imageanalyser`).

## Component reality (why D3 exists)

| Component | OP | MiDnight | Dual impl? |
|---|---|---|---|
| Dock | `modules/dock/` (3 files) | `modules/bar/components/Dock.qml` (a bar component) | no — different things |
| Bar | 2 trivial edits | 19 modified + 10 new | no — only MiDnight |
| Overview | 12 files | — | no — only OP |
| Wallpaper | 1 line | `services/Wallpapers.qml` 125→486 lines | no — only MiDnight |
| Clipboard, emoji, switcher, shimeji | — | yes | no — only MiDnight |
| Hotspot, BtAgent, GPU, themes | yes | — | no — only OP |
| **Lock centre, audio popout, background/clock, colours** | yes | yes | **yes — these four** |

## Verification

`hybrid/tools/smoke-matrix.sh` is the gate. It boots the shell headless
(`QT_QPA_PLATFORM=offscreen qs -p .`) under every preset and fails on QML errors.
Run it plus `qmllint` and `clang-format` before calling any change done — see the
`shell-verify` skill.

**This project only builds and runs on Linux** (Quickshell + Qt6 + Wayland/Hyprland).
Scaffolding may be authored anywhere; verification must happen on the Linux machine.
