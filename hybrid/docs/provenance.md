# Provenance ledger

Every file imported from an upstream gets a row here **in the same commit that imports it**.

All three upstreams are **GPL-3.0**, so the combined work is GPL-3.0 and there is no license
compatibility question. What we still owe: preserved copyright and authorship, preserved license
headers, and history that attributes the imported work. Keeping `git` history and this ledger
satisfies that; squashing an import into an anonymous commit does not.

## Source identifiers

| ID | Repository | Ref audited |
|---|---|---|
| `caelestia` | `caelestia-dots/shell` | `750e67d9` (2026-09-02) |
| `op` | `OVERxPOWERED/op-caelestia-shell` | `621339cf` (2026-08-25) |
| `midnight` | `dim-ghub/midnight-shell` | `bb7b5657` (2026-08-22) |
| `hybrid` | this repository | — |

## Import kinds

| Kind | Meaning |
|---|---|
| `baseline` | Arrived with the MiDnight fork. Not individually listed — the whole tree is `midnight` unless a row says otherwise. |
| `copied` | Imported byte-identical, or with only import-path changes. |
| `adapted` | Imported with real modifications. The row must say what changed and why. |
| `reimplemented` | Written by us based on the upstream behaviour, not its code. |
| `superseded` | Upstream later replaced it. Row records what we dropped (see T7). |

## Rules

1. One row per imported file. Group by feature; keep features in the order they were imported.
2. `adapted` rows need a one-line reason. "Cleanup" is not a reason.
3. When upstream changes a file we `adapted`, the sync branch updates the row's source commit.
4. Prefer `git cherry-pick -x` over copying — it records the source commit automatically and this
   ledger becomes a convenience index rather than the only record.
5. Binary assets (theme GIFs, sounds, shimeji sprites) get rows too. They are the easiest thing to
   lose attribution on and the most likely to carry third-party licensing of their own —
   **check asset provenance separately from code provenance.**

## Ledger

<!-- Add rows below. Keep the newest feature block at the bottom. -->

| Feature | Source | Source commit | Original path | Local path | Kind | Notes |
|---|---|---|---|---|---|---|
| _(baseline)_ | `midnight` | `bb7b5657` | _(whole tree)_ | _(whole tree)_ | `baseline` | Phase 0 fork point |
| video wallpaper | `midnight` | `bb7b5657` | `components/images/CachingVideo.qml` | _(removed)_ | `superseded` | `modules/background/Wallpaper.qml` plus `services/WallpaperPauser.qml` own the playback and pausing now. Dead in MiDnight too. |
| video wallpaper | `midnight` | `bb7b5657` | `services/VideoWallpaperPlayer.qml` | _(removed)_ | `superseded` | Its only user was `CachingVideo.qml`, here and in MiDnight. Orphaned by the row above. |
| bad apple | `midnight` | `bb7b5657` | `modules/background/BadAppleController.qml` | _(removed)_ | `superseded` | `BadApplePlayer` is the singleton the overlay and the toggles actually use. Dead in MiDnight too. |
| _(none)_ | `midnight` | `bb7b5657` | `modules/sidebar/TestComponent.qml` | _(removed)_ | `superseded` | Debug scaffolding: creates a red 100x100 FloatingWindow that logs on click. Never referenced, here or in MiDnight. |

### Kept deliberately

Not every unreferenced file is ours to remove. `components/misc/Ref.qml` is unused in all
three upstreams — including `caelestia` itself, since the C++ `ServiceRef` replaced it — so it
is upstream's to delete. `modules/notifications/QuickSharePrompt.qml` is the only incoming
transfer UI that exists and is kept as the design for a gap that is still open (T27). Both are
allowlisted in `hybrid/tools/dead-qml.py` with those reasons.

## Asset licensing watchlist

Imported assets that are **not** obviously original work of the fork author, to resolve before any
public release:

| Asset | Source | Status |
|---|---|---|
| `assets/shimeji/pusheen/*` (46) | `midnight` | **Resolved — removed.** Pusheen is a registered trademark of Pusheen Corp. Replaced by `assets/shimeji/sparkle/`, drawn here. |
| `assets/bongocat.gif` | `midnight` | **Resolved — removed.** Bongo Cat. Replaced by `assets/media-sparkle.gif`. |
| `assets/kurukuru.gif` | `midnight` | **Resolved — removed.** Replaced by `assets/session-sparkle.gif`. |
| `assets/dino/*` (8), `assets/dino.png` | `midnight` | **Resolved — removed.** The Chrome offline runner's T-Rex and cacti are Google's. Replaced by `assets/runner/` and `assets/no-notifs.png`. |
| `assets/sounds/*` (74 files) | `midnight` | Unresolved — check sample licensing |
| `assets/badapple.mp4` | `midnight` | Unresolved — Touhou fan animation. It *is* the easter egg, so it cannot be substituted; the honest options are to drop the feature or to ship it without the video and let a user supply one. |
| `assets/themes/{Deadpool,Gojo,Shinchan}/*` | `op` | Not imported. Arrives with OP's theme manager in Phase 5 — **do not import the art**. |

### Original work

`assets/shimeji/sparkle/`, `assets/runner/`, `assets/media-sparkle.gif`,
`assets/session-sparkle.gif` and `assets/no-notifs.png` are drawn by this project and carry
no third-party rights. They are generated, not hand-pixelled: `hybrid/tools/mascot/` holds
the SVG generator and the three scripts that render every frame, so the character can be
restyled or re-rendered at any size without redrawing it.

The design is deliberately not arbitrary — it is the four-pointed sparkle from
`assets/logo.svg`, in the same `#6AE5E1`, given a face. That is what makes the replacement
look like it belongs to this shell rather than like a substitute for something else.

GPL-3.0 covers the code. It does not launder third-party artwork that was bundled without a license.
