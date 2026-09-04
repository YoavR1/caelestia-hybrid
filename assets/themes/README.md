# Theme packs

A theme is a directory here whose name is what `paths.themeName` stores. Selecting one is a
matter of that single key: **Settings → Wallpaper & style → Themes**, or `>theme ` in the
launcher when `hybrid.features.themeManager` is on.

## What a theme contains

Five files, all optional in the sense that a missing one simply fails to load rather than
breaking the shell:

| file | where it appears | config key it supplies |
|---|---|---|
| `wallpaper.jpg` | the desktop | applied on selection, not a default |
| `lock.gif` | the lock screen | — |
| `media.gif` | under the dashboard's player controls | `paths.mediaGif` |
| `session.gif` | the session menu | `paths.sessionGif` |
| `notif.png` | shown when there are no notifications | `paths.noNotifsPic`, `paths.lockNoNotifsPic` |

## How selection works, and why it is a default rather than an assignment

A theme supplies the **default** for those `paths.*` keys; it does not write them. So if you
have set `paths.mediaGif` yourself, it stays yours through every theme change, and clearing it
falls back to the current theme. That is the same rule the hybrid presets use for feature flags
(D8 in `CLAUDE.md`): an explicit value always wins over a layer beneath it.

With no theme selected, the keys fall back to the shell's own bundled artwork.

## Adding your own

Make a directory, drop the files in, and it appears in the picker — the list is a
`FileSystemModel` watching this directory, so no restart is needed:

```
assets/themes/my-theme/{wallpaper.jpg,lock.gif,media.gif,session.gif,notif.png}
```

The displayed name is the directory name with `_` and `-` turned into spaces and each word
capitalised, so `deep-space` shows as "Deep Space".

## What ships here

Only `nebula`, and it is generated rather than drawn: `hybrid/tools/mascot/make-theme.py`
renders it from `sparkle.py`, the same four-pointed sparkle as `assets/logo.svg`, in a violet
palette. Re-running it reproduces the same files byte for byte.

```sh
./hybrid/tools/mascot/make-theme.py nebula
```

This is deliberate. OP-Caelestia ships Deadpool, Gojo and Shinchan packs, which are third-party
character IP, and this repository has already had to remove Pusheen, Bongo Cat and the Chrome
dino for the same reason — GPL-3.0 covers the code and launders nothing bundled alongside it.
A generated theme has no licensing question at all. Adding a palette to `PALETTES` in that
script is a new theme in one line; adding somebody else's artwork is a legal problem in one
commit.
