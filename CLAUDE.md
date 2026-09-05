# Caelestia Hybrid — project constitution

A single merged Quickshell desktop shell combining **MiDnight Shell** and **OP-Caelestia**
on top of upstream **Caelestia**. One shell, one config, one CLI — features toggled, not forks juggled.

> Read `hybrid/docs/architecture.md` for the reasoning and `hybrid/docs/traps.md` before touching
> anything in `modules/drawers/`, `services/`, `modules/lock/`, or `plugin/src/`.

## Status

**Phases 0-5 are done and merged to `main`. Phase 6 has not started; Phase 7 is half done.**

| phase | what | state |
|---|---|---|
| 0 | scaffold, docs, tooling, all four static gates brought to zero | done |
| 1 | offscreen smoke harness + preset matrix | done |
| 2 | 51 upstream commits merged, incl. the config-module rewrite | done |
| 3 | `hybrid.features` / `hybrid.variants` schema + Nexus page | done |
| 4 | OP's dock behind `hybrid.variants.dock` | done, and verified on hardware |
| 5 | OP overview, hotspot/BtAgent/Nmcli, GPU detection, themes | done |
| 6 | single CLI (D6) | done -- separate repo, [`YoavR1/caelestia-hybrid-cli`](https://github.com/YoavR1/caelestia-hybrid-cli) |
| 7 | the real variants | 3 of 6 wired: `audioPopout`, `overview`, `dock` |
| 8 | OP's pattern lock | satisfied by omission -- it is not in the tree (D10) |

Phase 6 was not cosmetic. Every CLI subcommand ran `qs -c caelestia`, which resolves a config
*by name* -- so on a machine with `midnight-shell-git` installed it drove the packaged shell
rather than this tree. That is T53, and it is what broke the launcher's Settings action. The
fork centralises that decision in `utils/instance.py`, which honours `$CAELESTIA_SHELL_PATH`
(for a checkout) and `$CAELESTIA_SHELL_CONFIG` before falling back to the historical default,
and carries a test that greps the subcommand tree for anyone re-hardcoding it.

Phase 7's remaining three -- `lockCentre`, `desktopClock`, `colours` -- have no second
implementation to select between: OP's side of each is edits to shared files rather than
separate files. They are declared in the schema and deliberately absent from the Nexus page
until that is resolved.

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
| `hybrid/tools/plugin-test.sh` | no test of any kind existed | 4 tests, 0 failures |
| `hybrid/tools/dead-signals.py` | didn't exist; 1 dead signal | 0 of 209 |
| `hybrid/tools/dead-qml.py` | didn't exist; 5 dead files | 0 of 367 |
| `hybrid/tools/shell-safety.py` | didn't exist; 15 injectable sites | 0 of 33 |
| `hybrid/tools/dead-config.py` | didn't exist; the T28 sweep was prose | 0 of 368, 15 allowlisted |
| `hybrid/tools/check-index-modes.sh` | didn't exist; 4 tools non-executable | clean |
| `hybrid/tools/hw-verify.sh` | didn't exist; the dock could not appear at all | 12 ok, 1 skipped |
| `hybrid/tools/singleton-members.py` | didn't exist; qmllint checks no singleton member at all | 2617 refs, 0 unexplained |
| `hybrid/tools/hw-audit.sh` | didn't exist; no IPC entry point had ever been driven | 51 ok, 0 skipped |

`./hybrid/tools/verify.sh` runs every row of that table in one go and prints GREEN or RED.
CI runs them too (`.github/workflows/smoke.yml` carries the last two, on headless sway).
`hybrid/tools/qml-section-order.py` is ours — the `section-order` fixer upstream's checker
lacks. `hybrid/tools/plugin-test.sh` is ours too, and runs the only executable tests in the
tree: the UKEY2 handshake, the `BeatTracker::beat` forward, the mDNS name decode and the
QuickShare payload frames.

The checkers in that table each guard a bug class every other gate is blind to, and each was
validated by being made to fail on purpose before being trusted — a checker that reports zero
because it is looking in the wrong place is worse than no checker (T23). That rule has earned
its place repeatedly: `hw-verify.sh` reported hover passing on a method that could not work
(T57), and `hw-audit.sh` scored a rejected IPC call as a pass on its first run.

`singleton-members.py` exists because **qmllint checks nothing about singleton members** — no
`qs.*` module has a qmldir, so it never resolves the type behind any of the 49 singletons here,
and `Colours.paletteXX.m3outlineYY` is three bogus accesses and zero findings. QML is silent at
runtime too. See T58.

Read `hybrid/docs/traps.md` T12–T35 before touching the harness; **T18 and T19 in
particular**, because qmllint silently lints against an installed `midnight-shell-git`
unless `--bare` is passed, and because the two `-Werror` build legs sat red through a phase
that reported CI green — they were never run locally, and a `clazy` finding is invisible to
`g++`.

`hybrid/docs/phase2-upstream-catchup.md` records every merge decision and the API mapping from
the old `ConfigObject` to `settings::ObjectNode`.

The remote is `https://github.com/YoavR1/caelestia-hybrid` and `main` is pushed. The shell runs
on real hardware; `hybrid/tools/hw-verify.sh` drives a live session and is the only gate that
can see a feature that loads correctly and is then unreachable (T54).

## Locked decisions

These were settled by source audit on 2026-09-02. Do not re-litigate without new evidence.

| # | Decision | Why |
|---|---|---|
| D1 | **Baseline is `dim-ghub/midnight-shell`**, not OP | MiDnight's delta is 4x OP's (33.5k vs 8.9k lines). Porting OP→MiDnight is weeks; the reverse is months. |
| D2 | **Nexus is upstream**, not an OP asset | `modules/nexus/` exists in all three. It is not a reason to prefer any baseline. |
| D3 | **Feature flags, not implementation selectors** | The forks are ~90% disjoint. Only 4 components have two real implementations. |
| D4 | **`hybrid.variants` is capped at ~6 entries** | If it grows, the design is drifting back toward a registry we deliberately rejected. |
| D5 | **Services are merged, never dual-implemented** | Both forks *extended* a shared service set. Their diffs are additive and non-overlapping. |
| D6 | **One CLI**, forked from `dim-ghub/midnight-cli` | All of them install the binary as `caelestia`, so they cannot coexist. Corrected 2026-09-05: the fork source is MiDnight's CLI, not upstream's, because MiDnight's already contains all 665 of upstream's commits (`merge-base` = upstream `HEAD`) and OP ships no CLI at all. There was never a merge to do. Its delta is +3664/−108 across 22 files, not ~850 lines. |
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
../caelestia-refs/cli-upstream.git  caelestia-dots/cli     (bare)
../caelestia-refs/cli-midnight.git  dim-ghub/midnight-cli  (bare)
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
| Overview | `modules/overview/` (12 files) | `modules/drawers/WorkspaceOverview.qml` (447 lines) | **yes — a fifth** |
| Wallpaper | 1 line | `services/Wallpapers.qml` 125→486 lines | no — only MiDnight |
| Clipboard, emoji, switcher, shimeji | — | yes | no — only MiDnight |
| Hotspot, BtAgent, GPU, themes | yes | — | no — only OP |
| **Lock centre, audio popout** | yes | yes | **yes — real dual sites** |
| Background/clock | — | 2-line delta | no — OP's `DesktopClock.qml` is byte-identical to upstream's |
| Colours | +52/−2 | yes | no — a *service*, and D5 merges services |

The Overview row was `no — only OP` until 2026-09-04. That was wrong: MiDnight ships
`modules/drawers/WorkspaceOverview.qml`, it is 447 lines, it is in this tree as part of the D1
baseline, and `hybrid.features.overview` already gates it from `modules/Shortcuts.qml`. Both
forks implement a workspace overview; they are different designs of the same component, which
is the definition this table uses for a dual site.

So there are **five** dual sites, not four, and OP's `modules/overview/` must not be imported
as a second boolean-gated implementation — that is precisely what D3 and D5 exist to prevent.
It is either left alone (MiDnight's works and is the baseline) or `overview` is promoted to
`hybrid.variants` in Phase 7. That was done, and the list then went the other way.

**`hybrid.variants` holds four entries: `lockCentre`, `audioPopout`, `overview`, `dock`.**
`desktopClock` and `colours` were declared and were removed on 2026-09-05, because neither is a
dual site and the evidence is mechanical: OP never touched `modules/background/DesktopClock.qml`
(its copy is identical to upstream's 161 lines), and its `services/Colours.qml` change is +52/−2
on a service, which D5 merges rather than dual-implements. Three of the four are wired. The
fourth, `lockCentre`, is a genuine dual site that Phase 8 blocks: OP's `PasswordInput.qml`
refers to `PatternGrid` eight times, so its lock centre cannot be imported without the
lock-screen bypass D10 rejects.

The lesson is worth keeping: a `hybrid.variants` entry needs *two implementations that exist as
files*, not two forks that both have opinions about an area. Four of the original six failed
that test on inspection, and two of them only failed once someone diffed the actual files.

## Verification

`hybrid/tools/smoke-matrix.sh` is the gate. It boots the shell headless
(`QT_QPA_PLATFORM=offscreen qs -p .`) under every preset and fails on QML errors.
Run it plus `qmllint` and `clang-format` before calling any change done — see the
`shell-verify` skill.

**This project only builds and runs on Linux** (Quickshell + Qt6 + Wayland/Hyprland).
Scaffolding may be authored anywhere; verification must happen on the Linux machine.
