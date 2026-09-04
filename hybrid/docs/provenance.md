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
| hotspot | `op` | `621339cf` | `services/Hotspot.qml` | `services/Hotspot.qml` | `adapted` | Four changes. `pollTimer.running` was an unconditional `true`, which runs `nmcli` every 10s forever once the singleton exists, active or not; it is now gated on `GlobalConfig.hybrid.features.hotspot` (adding `import Caelestia.Config`). Three are the credential path (T41): the default password was the published constant `"caelestia1234"`, now empty so nmcli generates a per-install PSK; `startProc`'s stdout was `console.log`ged, and that stdout is where nmcli prints the password, so it is no longer captured; and a successful start now calls `readSavedConfig()` so a generated key reaches the settings field. The rest is mechanical: `qml-section-order.py` moved functions and properties above the child objects, and `qmlformat` rejoined wrapped ternaries. |
| hotspot | `op` | `621339cf` | `modules/nexus/pages/network/HotspotPage.qml` | `modules/nexus/pages/network/HotspotPage.qml` | `adapted` | `modelData` in the connected-clients delegate is qualified through a new `id: clientEntry`, which `qmllint` requires (the tree's own shape, cf. `modules/nexus/common/EthernetSection.qml`). Otherwise formatter-only. Registered as sub-page index 7 of the Network `StackPage`. |
| theme packs | `op` | `621339cf` | `modules/launcher/services/ThemeManager.qml` | same | `adapted` | Dropped `GlobalConfig.save()`: SettingsFile debounces and persists writes itself since the Phase 2 config rewrite, and ConfigSingleton no longer exposes `save()`. |
| theme packs | `op` | `621339cf` | `modules/launcher/items/ThemeItem.qml` | same | `adapted` | `import qs.modules.launcher.services` carries a `qmllint disable unused-imports`: it is needed for the `ThemeManager.Theme` property type, and qmllint does not count a type used only in a property declaration -- removing it produces three `unresolved-type` warnings instead. |
| theme packs | `op` | `621339cf` | `modules/nexus/pages/wallandstyle/ThemeSelect.qml` | same | `adapted` | Same `save()` removal. Registered as sub-page index 6 of the Wallpaper & style `StackPage`. |
| theme packs | `op` | `621339cf` | `plugin/src/Caelestia/Config/userpaths.hpp` | `userpaths.{hpp,cpp}` | `reimplemented` | OP makes `sessionGif`/`mediaGif`/`lockGif`/`notifBg`/`defaultWall` read-only properties computed from `themeName`, defaulting to `"Shinchan"`. Ours keeps them as ordinary config keys and makes the *theme* supply their default, so a user who has set one specific path keeps it across a theme change -- the same override rule as D8. |
| theme packs | _(none)_ | — | `assets/themes/{Deadpool,Gojo,Shinchan}/*` (19 files) | _(not imported)_ | `rejected` | Third-party character IP -- Marvel's Deadpool, Gege Akutami's Gojo, Yoshito Usui's Shinchan. The same problem that already removed Pusheen, Bongo Cat and the Chrome dino. `assets/themes/nebula/` is generated instead by `hybrid/tools/mascot/make-theme.py` from this shell's own sparkle. |
| hotspot | `op` | `621339cf` | _(not imported)_ | _(deferred)_ | `deferred` | `services/BtAgent.qml` and `scripts/bt-agent.py` travel with Hotspot in the skill's import table but are an unrelated feature -- a Bluetooth pairing agent. Held for their own branch and flag rather than smuggled in behind `hybrid.features.hotspot`. |

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
| `assets/shimeji/pusheen/*` (46) | `midnight` | **Accepted by the owner, 2026-09-04 — restored** and back as the `shimeji.directory` default. Pusheen remains a registered trademark of Pusheen Corp. `assets/shimeji/sparkle/` was removed with the rest of the generated set; `hybrid/tools/mascot/make-sprites.py` regenerates it, and `shimeji.directory` is a config key, so switching back is that command plus one setting. |
| `assets/bongocat.gif` | `midnight` | **Accepted by the owner, 2026-09-04 — restored** as the `paths.mediaGif` default. `assets/media-sparkle.gif` was removed; `make-gifs.py` regenerates it. |
| `assets/kurukuru.gif` | `midnight` | **Accepted by the owner, 2026-09-04 — restored** as the `paths.sessionGif` default. `assets/session-sparkle.gif` was removed; `make-gifs.py` regenerates it. |
| `assets/dino/*` (8), `assets/dino.png` | `midnight` | **Accepted by the owner, 2026-09-04 — restored.** The Chrome offline runner's T-Rex and cacti remain Google's. `components/DinoGame.qml` hardcodes sprite paths, so unlike the others this one is a code change rather than a config key; `assets/runner/` was removed; `make-game.py` regenerates it, and the paths in that file are the whole switch. |
| `assets/sounds/*` (74 files) | `midnight` | **Accepted by the owner, 2026-09-04 — restored.** Android's stock tones: Aldebaran, Altair, Antares, Betelgeuse, Beat_Box_Android and 61 more, 16 MB of Google's library. They had been replaced by 16 synthesised files; the originals are back, byte-identical, on the same reasoning as `badapple.mp4` — MiDnight publishes them already and the repository is now public. The synthesised set is not deleted, it is unshipped: `hybrid/tools/mascot/make-sounds.py` regenerates it in one command, which is the remedy if a takedown ever arrives. |
| `assets/badapple.mp4` | `midnight` | **Accepted by the owner, 2026-09-04** — kept, and published with the repo. See the section below. Touhou fan animation. It *is* the easter egg, so it cannot be substituted; the honest options are to drop the feature or to ship it without the video and let a user supply one. |
| `assets/themes/{Deadpool,Gojo,Shinchan}/*` | `op` | Not imported. Arrives with OP's theme manager in Phase 5 — **do not import the art**. |

### Original work

`assets/shimeji/sparkle/`, `assets/runner/`, `assets/media-sparkle.gif`,
`assets/session-sparkle.gif`, `assets/no-notifs.png` and (until 2026-09-04) everything under `assets/sounds/`
are made by this project and carry no third-party rights. They are generated, not hand-pixelled: `hybrid/tools/mascot/` holds
the SVG generator and the three scripts that render every frame, so the character can be
restyled or re-rendered at any size without redrawing it.

The design is deliberately not arbitrary — it is the four-pointed sparkle from
`assets/logo.svg`, in the same `#6AE5E1`, given a face. That is what makes the replacement
look like it belongs to this shell rather than like a substitute for something else.

**The sounds below are no longer what ships.** MiDnight's originals were restored on 2026-09-04
(see the watchlist row and the section above); `make-sounds.py` still regenerates the synthesised
set, and this is kept as the description of that fallback rather than of the current tree.

The sounds are additive synthesis from the standard library — no numpy, no sox, nothing to
install. Every tone is built from a fast raised-cosine attack, an exponential body and a
cosine release, so each one starts and ends at exactly zero and cannot click; the notes are
one major pentatonic scale, so no two sounds clash when they overlap. `synth.py` is the
instrument and `make-sounds.py` is the score.

**What was verified, and what was not.** Every file was checked programmatically for peak
level (0.72, headroom left deliberately), a first sample of exactly zero, negligible DC
offset, and the intended pitch via a Goertzel filter; the envelopes were rendered as
waveforms and inspected. Nobody has *listened* to them. The design choices are conventional
ones for interface sound, but if any of them is unpleasant in use, that is the check that was
not run.

GPL-3.0 covers the code. It does not launder third-party artwork that was bundled without a license.

## The repository is public, with the watchlist unresolved (2026-09-04)

The owner made this repository public on 2026-09-04 with `assets/badapple.mp4` still present and
with every other watchlist file still reachable in git history — deleting a file in a later commit
removes it from the working tree, not from the repository, and a public repo publishes history.
152 objects across `badapple.mp4`, `shimeji/pusheen/`, `bongocat.gif`, `kurukuru.gif`,
`assets/dino*` and `assets/sounds/` are therefore published.

This is recorded rather than argued. The reasoning, so a later reader does not have to reconstruct
it:

- **Forking Caelestia was never the question.** All three upstreams are GPL-3.0 and public;
  building on them is exactly what the licence is for. The watchlist has only ever been about
  third-party *media* that MiDnight bundled alongside its code.
- **The material is already public at its source.** `dim-ghub/midnight-shell` is a public GPL-3.0
  repository carrying the identical `badapple.mp4` — same 7,423,554 bytes — along with the rest.
  Republishing it here exposes nothing that is not already exposed there.
- **"Upstream does it too" is shared exposure, not a licence.** It remains true that a Touhou
  fan animation, Pusheen (a registered trademark of Pusheen Corp), Bongo Cat and Google's T-Rex
  are not GPL-3.0 and are not ours to relicense. The realistic consequence is a takedown request,
  not a lawsuit, and the remedy would be the history purge described below.
- **What was gained.** GitHub Actions is free and unlimited for public repositories. The account
  had hit its private-repo minute allowance and every CI job was refusing to start.

**If this has to be undone**, deleting the files is not enough — the paths must be purged from all
history with `git filter-repo`, which rewrites every commit SHA, breaks open PRs and diverges every
clone. Doing it while work is in flight is worse than doing it deliberately later.

**Every asset in this tree is now byte-identical to one in an upstream.** Audited rather than
assumed, in both directions: 148 files match a fork blob-for-blob, none differ, none is
unaccounted for, and nothing MiDnight ships is missing here.

The generated replacements were removed along the way -- `assets/shimeji/sparkle/`,
`assets/runner/`, `media-sparkle.gif`, `session-sparkle.gif`, `no-notifs.png` and the sixteen
synthesised sounds. Deleting them costs nothing, because the tools in `hybrid/tools/mascot/`
rebuild each set in one command, and that is the point of keeping the tools: they are the remedy
if a takedown ever arrives, not decoration.

    make-sprites.py   assets/shimeji/sparkle/     shimeji.directory
    make-gifs.py      media-/session-sparkle.gif  paths.mediaGif, paths.sessionGif
    make-idle.py      no-notifs.png               paths.noNotifsPic, paths.lockNoNotifsPic
    make-game.py      assets/runner/              hardcoded in components/DinoGame.qml
    make-sounds.py    assets/sounds/              audio.sounds.*

Four of the five are config keys. `DinoGame.qml` hardcodes its sprite paths, so that one needs an
edit -- worth knowing before it is needed rather than after.

`assets/themes/nebula/` is the exception and stays: it is a new feature's content rather than a
substitute for anything, and no fork has an equivalent.
