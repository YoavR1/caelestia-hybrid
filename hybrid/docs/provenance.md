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

## Asset licensing watchlist

Imported assets that are **not** obviously original work of the fork author, to resolve before any
public release:

| Asset | Source | Status |
|---|---|---|
| `assets/themes/{Deadpool,Gojo,Shinchan}/*` | `op` | **Unresolved** — character art/GIFs, likely third-party copyright. Do not ship without clearing. |
| `assets/shimeji/*` (46 files) | `midnight` | Unresolved — check sprite origin |
| `assets/sounds/*` (74 files) | `midnight` | Unresolved — check sample licensing |
| `assets/dino/*` | `midnight` | Unresolved |

GPL-3.0 covers the code. It does not launder third-party artwork that was bundled without a license.
