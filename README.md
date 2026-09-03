<h1 align=center>Caelestia Hybrid</h1>

<div align=center>

One Quickshell desktop shell merging **MiDnight Shell** and **OP-Caelestia** on top of
upstream **Caelestia**. One shell, one config, one CLI — features toggled, not forks juggled.

</div>

> [!NOTE]
> This is a merge of three GPL-3.0 projects: [caelestia-dots/shell](https://github.com/caelestia-dots/shell)
> (upstream), [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) (the
> baseline), and [OVERxPOWERED/op-caelestia-shell](https://github.com/OVERxPOWERED/op-caelestia-shell).
> See [Credits](#credits) and `hybrid/docs/provenance.md`.

## Features

The two forks are about 90% disjoint, so almost everything they added is a feature that is
either present or absent rather than a choice between two implementations. Each one is a
flag under `hybrid.features` in `shell.json`, and the settings app (Nexus) has a page for
them.

| flag | what it turns on |
|---|---|
| `clipboard` | clipboard history in the launcher |
| `emojiPicker` | emoji search in the launcher |
| `windowSwitcher` | window switching from the launcher |
| `keybindViewer` | a browsable list of your Hyprland keybinds |
| `dock` | the MacOS-style app dock in the bar |
| `overview` | the workspace overview drawer |
| `videoWallpaper` | GIF and video wallpapers, paused when nothing can see them |
| `wallhaven` | browsing and setting wallpapers from wallhaven.cc |
| `floatingLyrics` | synced lyrics on the desktop |
| `shimeji` | desktop pets |
| `badApple` | a shader that plays Bad Apple through the shell's own UI material |
| `dino` | the Chrome runner, in the notification dock |

Not flagged, because they are not optional: the bar's Material workspace icons, DND toggle
and drag-and-drop component editor; the dashboard's terminal, Wallhaven and weather tabs;
dynamic wallpaper recolouring; and Bezel Mode.

Still to come (Phase 5), each behind a flag of its own when it lands: OP's standalone
overview and dock windows, its hotspot, its theme manager and its Bluetooth agent.

### Presets

`hybrid.preset` picks a starting set. Anything you change afterwards stays changed — the
preset *name* is what gets stored, not its expanded values, so a preset can be improved later
and existing configs receive the improvement.

| preset | what it turns on |
|---|---|
| `recommended` | the default: everything both forks do well, novelties off |
| `midnight` | MiDnight as it ships — its features, none of OP's |
| `op` | OP as it ships |

Four components genuinely exist in both forks — the lock centre, the audio popout, the
desktop clock and the colour system. Those live under `hybrid.variants` rather than
`hybrid.features`, because the choice there is *which* implementation, not whether. Each
currently has one implementation; the selector appears when the second lands.

## Installation

> [!IMPORTANT]
> There is no package for this yet — no AUR entry, no flake URL, no installer. Build it from
> source. The instructions below are the upstream ones and are the only supported path.

Dependencies:

-   [`caelestia-cli`](https://github.com/caelestia-dots/cli) — required; the shell's IPC and
    most of its shortcuts go through it.
    MiDnight ships a fork of it (`dim-ghub/midnight-cli`, +849 lines) that some of its
    features expect — video wallpaper control among them. Both install their binary as
    `caelestia`, so you cannot have both, and the merged CLI does not exist yet. Until it
    does, install upstream's and expect those specific extras to be inert.
-   [`quickshell-git`](https://quickshell.outfoxxed.me) - this has to be the git version, not the latest tagged version
-   [`ddcutil`](https://github.com/rockowitz/ddcutil)
-   [`brightnessctl`](https://github.com/Hummer12007/brightnessctl)
-   [`app2unit`](https://github.com/Vladimir-csp/app2unit)
-   [`libcava`](https://github.com/LukashonakV/cava)
-   [`networkmanager`](https://gitlab.freedesktop.org/NetworkManager/NetworkManager)
-   [`lm_sensors`](https://github.com/lm-sensors/lm-sensors)
-   [`aubio`](https://github.com/aubio/aubio)
-   [`libpipewire`](https://github.com/PipeWire/pipewire)
-   [`libqalculate`](https://github.com/Qalculate/libqalculate)
-   [`power-profiles-daemon`](https://gitlab.freedesktop.org/upower/power-profiles-daemon)
-   [`protobuf`](https://github.com/protocolbuffers/protobuf) and
    [`openssl`](https://github.com/openssl/openssl) — for Quick Share
-   [`ttf-material-symbols-variable`](https://github.com/google/material-design-icons)
-   [`ttf-rubik-vf`](https://github.com/googlefonts/rubik)
-   [`ttf-cascadia-code-nerd`](https://github.com/ryanoasis/nerd-fonts)
-   `qt6-base`
-   `qt6-declarative`

Build dependencies:

-   [`cmake`](https://gitlab.kitware.com/cmake/cmake)
-   [`ninja`](https://github.com/ninja-build/ninja)
-   `qt6-shadertools`

> [!IMPORTANT]
> The commands below (and in the "Updating" section) assume `$XDG_CONFIG_HOME` is set.
> If it is unset, substitute it with the path to your config folder (typically `~/.config`).

Clone into `$XDG_CONFIG_HOME/quickshell/caelestia`, then build and install with `cmake`:

```sh
cd $XDG_CONFIG_HOME/quickshell
git clone <this repository> caelestia

cd caelestia
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/
cmake --build build
sudo cmake --install build
```

> [!NOTE]
> `VERSION` and `GIT_REVISION` are parsed from the repository's remote tags. Until this repo
> has a remote, pass them explicitly: `-DVERSION=0.0.0 -DGIT_REVISION=$(git rev-parse HEAD)`.

> [!TIP]
> You can customise the installation location via the CMake flags `INSTALL_LIBDIR`, `INSTALL_QMLDIR`, and
> `INSTALL_QSCONFDIR` for the libraries (e.g. the version helper), QML plugin, and Quickshell config directories
> respectively. If you set the `INSTALL_LIBDIR` flag, the `CAELESTIA_LIB_DIR` variable must also be set to
> the same directory in your system's environment.
>
> For example, installing to `~/.config/quickshell/caelestia` for easy local changes:
>
> ```sh
> mkdir -p ~/.config/quickshell/caelestia
> cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DINSTALL_QSCONFDIR="$HOME/.config/quickshell/caelestia"
> cmake --build build
> sudo cmake --install build
> sudo chown -R $USER ~/.config/quickshell/caelestia
> ```

### Nix

> [!WARNING]
> Limited/no support for NixOS. Proceed at your own risk.

The flake is inherited from upstream and builds, but there is no URL to fetch it from yet, so
it has to be referenced by path:

```sh
nix run /path/to/this/repo
```

The package is exposed as `packages.<system>.default`. The default package does not enable
the CLI, which most functionality needs — use the `with-cli` package instead.

### Development

`hybrid/tools/dev-shell.sh` runs the shell from the working tree against an isolated config
and state directory, so it never touches a running session. See `hybrid/docs/` for the
architecture, the known traps, and the verification gate.

## Components

-   Widgets: [`Quickshell`](https://quickshell.outfoxxed.me)
-   Window manager: [`Hyprland`](https://hyprland.org)
-   Dots: [`caelestia`](https://github.com/caelestia-dots)

## Global Shortcuts

All keybinds are accessible via Hyprland [global shortcuts](https://wiki.hypr.land/Configuring/Basics/Binds#dbus-global-shortcuts).

### Available Shortcuts

| Shortcut Name | Description |
|---------------|-------------|
| `caelestia:controlCenter` | Open control center |
| `caelestia:launcher` | Toggle launcher |
| `caelestia:dashboard` | Toggle dashboard |
| `caelestia:session` | Toggle session menu |
| `caelestia:sidebar` | Toggle sidebar |
| `caelestia:utilities` | Toggle utilities panel |
| `caelestia:emoji` | Open emoji picker |
| `caelestia:clipboard` | Open clipboard history |
| `caelestia:windowSwitcher` | Open window switcher |
| `caelestia:keybinds` | Open keybinds list |
| `caelestia:wallpaper` | Open wallpaper picker |
| `caelestia:showall` | Toggle all UI elements |
| `caelestia:terminal` | Toggle terminal drawer |

### Hyprland Keybind Examples

To bind these shortcuts in Hyprland, add to your config:

```conf
# Launcher and UI elements
bind = SUPER, SPACE, global, caelestia:launcher
bind = SUPER, RETURN, global, caelestia:launcher
bind = SUPER, S, global, caelestia:controlCenter

# Added by the forks
bind = SUPER, E, global, caelestia:emoji
bind = SUPER, V, global, caelestia:clipboard
bind = SUPER, W, global, caelestia:windowSwitcher
bind = SUPER, K, global, caelestia:keybinds
bind = SUPER, B, global, caelestia:wallpaper
bind = SUPER, T, global, caelestia:terminal

# Other toggles
bind = SUPER, D, global, caelestia:dashboard
bind = SUPER, N, global, caelestia:sidebar
bind = SUPER, M, global, caelestia:utilities
```

## Migration from upstream Caelestia

Coming from upstream `caelestia-dots/shell`, your `shell.json` keeps working — every key
below is additive and every one of them has a default. Add them only if you want to set them
to something other than that default:

```json
"launcher": {
    "favouriteEmojis": [],
    "favouriteClips": []
},
"shimeji": {
    "enabled": false,
    "path": "root:/assets/shimeji/pusheen/",
    "count": 1,
    "autoHide": true,
    "excludedScreens": [],
    "screenCounts": {}
},
"background": {
    "videoWallpaperPaused": false,
    "videoWallpaperSoundEnabled": false,
    "videoWallpaperPauseOnFullscreen": false,
    "videoWallpaperPauseOnTiled": false,
    "videoWallpaperPauseOnAllDisplays": false,
    "videoWallpaperMuteOnMedia": false,
    "desktopLyrics": {
        "enabled": false,
        "autoHide": true,
        "scale": 1.0,
        "position": "bottom-center",
        "alignment": 1,
        "invertColors": false,
        "background": {
            "enabled": false,
            "opacity": 0.7,
            "blur": true
        },
        "shadow": {
            "enabled": true,
            "opacity": 0.7,
            "blur": 0.4
        }
    }
},
"utilities": {
    "quickToggles": [
        { "id": "wallpaper", "enabled": true },
        { "id": "badapple", "enabled": true },
        { "id": "pauseWallpaper", "enabled": true }
    ]
}
```

## Usage

You can start the shell by running `caelestia shell -d` (preferred) or `qs -c caelestia -n -d`.
You may omit `-d` from the command to keep the shell attached to the current terminal if necessary,
though you likely want it to be detached (so it doesn't close when the terminal is closed).

If using the [Caelestia dotfiles][dots-repo], the shell will be autostarted on login
via a `hl.on("hyprland.start", ...)` function in the Hyprland config.

### Shortcuts/IPC

All keybinds are accessible via Hyprland [global shortcuts](https://wiki.hypr.land/Configuring/Basics/Binds#dbus-global-shortcuts).
If using the entire caelestia dots, the keybinds are already configured for you.
Otherwise, [this file](https://github.com/caelestia-dots/caelestia/blob/main/hypr/hyprland/keybinds.lua#L52-L67)
contains an example on how to use global shortcuts.

All IPC commands can be accessed via `caelestia shell ...`, for example:

```sh
caelestia shell mpris getActive trackTitle
```

You can view the list of available IPC commands by running `caelestia shell -s`.

### PFP/Wallpapers

The profile picture for the dashboard is read from the file `~/.face`. You can set it by clicking it in the dashboard,
or by manually copying or symlinking your image to the path.

The wallpapers for the wallpaper switcher are read from `~/Pictures/Wallpapers`
by default. To change it, modify `paths.wallpaperDir` in `~/.config/caelestia/shell.json`.

To set the wallpaper, you can type `>wallpaper` in the launcher to open the wallpaper switcher.
Alternatively, you can also use `caelestia wallpaper -f <path_to_wallpaper>` to set the wallpaper directly.
Use `caelestia wallpaper -h` for more info about this command.

## Updating

There is no package yet, so updating means pulling and rebuilding:

```sh
cd $XDG_CONFIG_HOME/quickshell/caelestia
git pull
cmake --build build
sudo cmake --install build
```

Restart the shell afterwards with `caelestia shell -d` (or `caelestia shell kill` first, if
one is already running).

## Uninstalling

`cmake --install` writes no manifest that can be replayed, so removal is manual: delete the
clone at `$XDG_CONFIG_HOME/quickshell/caelestia` and the files listed in
`build/install_manifest.txt`.

> [!CAUTION]
> Do not run any script that offers to "clean" the install by removing a config directory or
> killing every Quickshell process. `~/.config/caelestia` holds *your* settings, not the
> shell's code, and a blanket kill takes down whatever else you are running. Nothing in this
> repository does either, and nothing added to it should.

## Configuring

All configuration options belong in `~/.config/caelestia/shell.json`. This file is _not_ created by
default; you must create it manually. Options that you omit from the config file will use their default
values.

### The hybrid section

`hybrid` is the only part of the schema that is not upstream's. It holds the preset name and
the feature flags described under [Features](#features):

```json
{
    "hybrid": {
        "preset": "recommended",
        "features": {
            "dock": true,
            "overview": true,
            "clipboard": true,
            "emojiPicker": true,
            "windowSwitcher": true,
            "keybindViewer": true,
            "videoWallpaper": true,
            "wallhaven": true,
            "floatingLyrics": true,
            "shimeji": false,
            "badApple": false,
            "dino": false
        }
    }
}
```

Every flag defaults to whatever the selected preset says, so a config that names only a
preset is complete. A flag you set explicitly is yours and is never re-resolved when the
preset changes — that is the whole point of storing the preset's *name*.

Where there is something to create, a flag prevents it being created rather than hiding it —
under the `all-off` preset the gated panels report zero instantiations, not zero visible
pixels. A few flags gate only a control's visibility, where nothing separate exists to
create.

`hybrid` is global. Per-monitor overrides do not apply to it, because a feature flag per
monitor is meaningless.

### Per-monitor configuration

You can configure per-monitor options in `~/.config/caelestia/monitors/<monitor_name>/shell.json`.
List the names of your available monitors by running:

```sh
hyprctl monitors -j | jq -r '.[].name'
```

Options set in these files will **override** the respective options in the global config. Any options not present in
per-monitor configs will inherit their values from the global config.


For example, to automatically hide the bar on the monitor named `DP-1`:

**`~/.config/caelestia/monitors/DP-1/shell.json`**

```json
{
    "bar": {
        "persistent": false
    }
}
```

> [!NOTE]
> Not all options respect per-monitor overrides. Most notably, the following options will only read
> from the global config, and ignore the respective option in per-monitor config files.
>
> <details><summary>Ignored options</summary>
>
> - `appearance` (`anim`, `transparency`)
> - `general` (`logo`, `apps`, `idle`, `battery`)
> - `bar.workspaces` (`perMonitorWorkspaces`, `specialWorkspaceIcons`, `windowIcons`, `wsIcons`)
> - `bar.tray` (`iconSubs`, `hiddenIcons`)
> - `dashboard` (`mediaUpdateInterval`, `resourceUpdateInterval`)
> - `launcher` (`specialPrefix`, `actionPrefix`, `enableDangerousActions`, `vimKeybinds`,
>   `favouriteApps`, `hiddenApps`, `actions`)
> - `launcher.useFuzzy` (`apps`, `actions`, `schemes`, `variants`, `wallpapers`)
> - `notifs` (`expire`, `fullscreen`, `defaultExpireTimeout`, `fullscreenExpireTimeout`, `actionOnClick`)
> - `lock` (`enableFprint`, `maxFprintTries`)
> - `nexus` (`networkRescanInterval`)
> - `utilities.toasts` (all except `fullscreen`)
> - `utilities.vpn` (`enabled`, `provider`)
> - `services` (`weatherLocation`, `useFahrenheit`, `useFahrenheitPerformance`, `useTwelveHourClock`,
>   `gpuType`, `visualiserBars`, `audioIncrement`, `brightnessIncrement`, `maxVolume`, `smartScheme`,
>   `defaultPlayer`, `playerAliases`, `lyricsBackend`)
> - `paths` (`wallpaperDir`, `lyricsDir`)
>
> </details>

### Example configuration

> [!WARNING]
> The example configuration includes **ALL** configuration options in `shell.json`. It is
> **not** recommended to copy and paste this entire configuration into `shell.json`,
> as options or their default values may change across updates, resulting in a stale config.
>
> This is meant to serve as a reference of all the available options, and you should
> <ins>only add the ones you want to change</ins> to `shell.json`.

<details><summary>Example config</summary>

```json
{
    "ai": {
        "activeOllamaModel": "llama3",
        "activeProvider": "ollama",
        "defaultOllamaModel": "llama3",
        "defaultProvider": "ollama",
        "enableCelestialMode": false,
        "enableOllama": true,
        "ollamaHistoryJson": "[]",
        "ollamaModel": "llama3",
        "ollamaUrl": "http://localhost:11434",
        "saveChatHistory": true,
        "snapToDefaultOllama": true
    },
    "appearance": {
        "anim": {
            "durations": {
                "scale": 1
            }
        },
        "deformScale": 1,
        "font": {
            "body": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 16,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 12,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                }
            },
            "clock": "Rubik",
            "headline": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 32,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 28,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 24,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                }
            },
            "icon": {
                "extraLarge": {
                    "family": "",
                    "italic": false,
                    "size": 36,
                    "vaxes": {},
                    "weight": 400
                },
                "family": "Material Symbols Rounded",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 24,
                    "vaxes": {},
                    "weight": 400
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 18,
                    "vaxes": {},
                    "weight": 400
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 15,
                    "vaxes": {},
                    "weight": 400
                }
            },
            "label": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 12,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 11,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 400
                }
            },
            "mono": {
                "family": "CaskaydiaCove NF",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 16,
                    "vaxes": {},
                    "weight": 400
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {},
                    "weight": 400
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 12,
                    "vaxes": {},
                    "weight": 400
                }
            },
            "scale": 1,
            "title": {
                "family": "GoogleSansFlex",
                "large": {
                    "family": "",
                    "italic": false,
                    "size": 22,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "medium": {
                    "family": "",
                    "italic": false,
                    "size": 16,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                },
                "small": {
                    "family": "",
                    "italic": false,
                    "size": 14,
                    "vaxes": {
                        "ROND": 25
                    },
                    "weight": 500
                }
            },
            "workspaces": "Rubik"
        },
        "padding": {
            "scale": 1
        },
        "pitchBlack": false,
        "rounding": {
            "scale": 1
        },
        "spacing": {
            "scale": 1
        },
        "transparency": {
            "base": 0.85,
            "enabled": false,
            "layers": 0.4
        }
    },
    "audio": {
        "sounds": {
            "cameraClick": true,
            "chargingStarted": true,
            "disabledNotifApps": [],
            "effectTick": true,
            "enabled": true,
            "lock": true,
            "lowBattery": true,
            "notificationSound": "Iapetus.wav",
            "notificationVolume": 1,
            "screenRecord": true,
            "sfxVolume": 1,
            "unlock": true
        }
    },
    "general": {
        "logo": "",
        "showOverFullscreen": false,
        "mediaGifSpeedAdjustment": 300,
        "sessionGifSpeed": 0.7,
        "apps": {
            "terminal": ["foot"],
            "audio": ["pwvucontrol"],
            "playback": ["mpv"],
            "explorer": ["thunar"]
        },
        "idle": {
            "lockBeforeSleep": true,
            "inhibitWhenAudio": true,
            "inhibitWhenCharging": false,
            "timeouts": [
                {
                    "timeout": 180,
                    "idleAction": "lock",
                    "inhibitWhenAudio": false,
                    "inhibitWhenCharging": false,
                    "respectInhibitors": true
                },
                {
                    "timeout": 300,
                    "idleAction": "dpms off",
                    "returnAction": "dpms on"
                },
                {
                    "timeout": 600,
                    "idleAction": ["suspendThenHibernate"]
                }
            ]
        },
        "battery": {
            "warnLevels": [
                {
                    "level": 20,
                    "title": "Low battery",
                    "message": "You might want to plug in a charger",
                    "icon": "battery_android_frame_2"
                },
                {
                    "level": 10,
                    "title": "Did you see the previous message?",
                    "message": "You should probably plug in a charger <b>now</b>",
                    "icon": "battery_android_frame_1"
                },
                {
                    "level": 5,
                    "title": "Critical battery level",
                    "message": "PLUG THE CHARGER RIGHT NOW!!",
                    "icon": "battery_android_alert",
                    "critical": true
                }
            ],
            "criticalLevel": 3
        }
    },
    "background": {
        "desktopClock": {
            "background": {
                "blur": true,
                "enabled": false,
                "opacity": 0.7
            },
            "enabled": false,
            "invertColors": false,
            "position": "bottom-right",
            "scale": 1,
            "shadow": {
                "blur": 0.4,
                "enabled": true,
                "opacity": 0.7
            }
        },
        "desktopLyrics": {
            "alignment": 1,
            "autoHide": true,
            "background": {
                "blur": true,
                "enabled": false,
                "opacity": 0.7
            },
            "enabled": false,
            "invertColors": false,
            "position": "bottom-center",
            "scale": 1,
            "shadow": {
                "blur": 0.4,
                "enabled": true,
                "opacity": 0.7
            }
        },
        "enabled": true,
        "videoWallpaperMuteOnMedia": false,
        "videoWallpaperPauseOnAllDisplays": false,
        "videoWallpaperPauseOnFullscreen": false,
        "videoWallpaperPauseOnTiled": false,
        "videoWallpaperPaused": false,
        "videoWallpaperSoundEnabled": false,
        "visualiser": {
            "autoHide": true,
            "blur": false,
            "enabled": false,
            "rounding": 1,
            "spacing": 1
        },
        "wallpaperEnabled": true
    },
    "bar": {
        "activeWindow": {
            "compact": false,
            "inverted": false,
            "showOnHover": true
        },
        "clock": {
            "background": false,
            "showDate": false,
            "showIcon": true
        },
        "dock": {
            "monitorCenter": true,
            "recolourIcons": false
        },
        "dragThreshold": 20,
        "peripheralBatteryExcluded": [],
        "statusIcons": [
            {
                "id": "lockStatus",
                "enabled": true
            },
            {
                "id": "audio",
                "enabled": false
            },
            {
                "id": "microphone",
                "enabled": false
            },
            {
                "id": "kbLayout",
                "enabled": false
            },
            {
                "id": "network",
                "enabled": true
            },
            {
                "id": "bluetooth",
                "enabled": true
            },
            {
                "id": "battery",
                "enabled": true
            },
            {
                "id": "peripheralBattery",
                "enabled": false
            },
            {
                "id": "notifications",
                "enabled": true
            }
        ],
        "tray": {
            "background": false,
            "compact": false,
            "hiddenIcons": [],
            "iconSubs": [],
            "recolour": false
        },
        "workspaces": {
            "activeIndicator": true,
            "activeLabel": " \udb82\udfaf",
            "activeTrail": false,
            "capitalisation": "preserve",
            "label": "\uf444 ",
            "maxWindowIcons": 5,
            "occupiedBg": false,
            "occupiedLabel": " \udb82\udfaf",
            "perMonitorWorkspaces": true,
            "showWindows": true,
            "showWindowsOnSpecialWorkspaces": true,
            "shown": 5,
            "specialWorkspaceIcons": [],
            "useIcon": true,
            "windowIcons": [
                {
                    "icon": "sports_esports",
                    "regex": "steam(_app_(default|[0-9]+))?"
                }
            ],
            "wsIcons": []
        }
    },
    "border": {
        "rounding": 25,
        "smoothing": 20,
        "thickness": 10
    },
    "dashboard": {
        "colorizeMediaGif": true,
        "dragThreshold": 50,
        "enabled": true,
        "mediaUpdateInterval": 500,
        "performance": {
            "showBattery": true,
            "showCpu": true,
            "showGpu": true,
            "showMemory": true,
            "showNetwork": true,
            "showStorage": true
        },
        "profilePicShape": 9,
        "resourceUpdateInterval": 1000,
        "showDashboard": true,
        "showHyprlandSplash": false,
        "showMedia": true,
        "showOnHover": true,
        "showPerformance": true,
        "showTerminal": true,
        "showWeather": true
    },
    "enabled": true,
    "general": {
        "apps": {
            "audio": [
                "pavucontrol"
            ],
            "explorer": [
                "thunar"
            ],
            "playback": [
                "mpv"
            ],
            "terminal": [
                "foot"
            ]
        },
        "battery": {
            "criticalLevel": 3,
            "warnLevels": [
                {
                    "icon": "battery_android_frame_2",
                    "level": 20,
                    "message": "You might want to plug in a charger",
                    "title": "Low battery"
                },
                {
                    "icon": "battery_android_frame_1",
                    "level": 10,
                    "message": "You should probably plug in a charger <b>now</b>",
                    "title": "Did you see the previous message?"
                },
                {
                    "critical": true,
                    "icon": "battery_android_alert",
                    "level": 5,
                    "message": "PLUG THE CHARGER RIGHT NOW!!",
                    "title": "Critical battery level"
                }
            ]
        },
        "idle": {
            "inhibitWhenAudio": true,
            "lockBeforeSleep": true,
            "timeouts": [
                {
                    "idleAction": "lock",
                    "timeout": 180
                },
                {
                    "idleAction": "dpms off",
                    "returnAction": "dpms on",
                    "timeout": 300
                },
                {
                    "idleAction": [
                        "loginctl",
                        "suspend"
                    ],
                    "timeout": 600
                }
            ]
        },
        "logo": "",
        "mediaGifSpeedAdjustment": 300,
        "sessionGifSpeed": 0.7,
        "showOverFullscreen": false
    },
    "launcher": {
        "actionPrefix": ">",
        "actions": [
            {
                "command": [
                    "autocomplete",
                    "calc"
                ],
                "description": "Do simple math equations (powered by Qalc)",
                "icon": "calculate",
                "name": "Calculator"
            },
            {
                "command": [
                    "autocomplete",
                    "scheme"
                ],
                "description": "Change the current colour scheme",
                "icon": "palette",
                "name": "Scheme"
            },
            {
                "command": [
                    "autocomplete",
                    "wallpaper"
                ],
                "description": "Change the current wallpaper",
                "icon": "image",
                "name": "Wallpaper"
            },
            {
                "command": [
                    "autocomplete",
                    "variant"
                ],
                "description": "Change the current scheme variant",
                "icon": "colors",
                "name": "Variant"
            },
            {
                "command": [
                    "caelestia",
                    "wallpaper",
                    "-r"
                ],
                "description": "Switch to a random wallpaper",
                "icon": "casino",
                "name": "Random"
            },
            {
                "command": [
                    "setMode",
                    "light"
                ],
                "description": "Change the scheme to light mode",
                "icon": "light_mode",
                "name": "Light"
            },
            {
                "command": [
                    "setMode",
                    "dark"
                ],
                "description": "Change the scheme to dark mode",
                "icon": "dark_mode",
                "name": "Dark"
            },
            {
                "command": [
                    "loginctl",
                    "poweroff"
                ],
                "dangerous": true,
                "description": "Shutdown the system",
                "icon": "power_settings_new",
                "name": "Shutdown"
            },
            {
                "command": [
                    "loginctl",
                    "reboot"
                ],
                "dangerous": true,
                "description": "Reboot the system",
                "icon": "cached",
                "name": "Reboot"
            },
            {
                "command": [
                    "hyprctl",
                    "dispatch",
                    "exit"
                ],
                "dangerous": true,
                "description": "Log out of the current session",
                "icon": "exit_to_app",
                "name": "Logout"
            },
            {
                "command": [
                    "loginctl",
                    "lock-session"
                ],
                "description": "Lock the current session",
                "icon": "lock",
                "name": "Lock"
            },
            {
                "command": [
                    "loginctl",
                    "suspend"
                ],
                "description": "Suspend then hibernate",
                "icon": "bedtime",
                "name": "Sleep"
            },
            {
                "command": [
                    "caelestia",
                    "shell",
                    "nexus",
                    "open"
                ],
                "description": "Configure the shell",
                "icon": "settings",
                "name": "Settings"
            },
            {
                "command": [
                    "autocomplete",
                    "emoji"
                ],
                "description": "Pick an emoji to copy",
                "icon": "emoji_emotions",
                "name": "Emoji"
            },
            {
                "command": [
                    "autocomplete",
                    "clipboard"
                ],
                "description": "View clipboard history",
                "icon": "content_paste",
                "name": "Clipboard"
            },
            {
                "command": [
                    "autocomplete",
                    "windows"
                ],
                "description": "Switch to another window",
                "enabled": true,
                "icon": "apps",
                "name": "Windows"
            },
            {
                "command": [
                    "autocomplete",
                    "keybinds"
                ],
                "description": "View all keybinds",
                "icon": "keyboard",
                "name": "Keybinds"
            }
        ],
        "dragThreshold": 50,
        "enableDangerousActions": false,
        "enabled": true,
        "favouriteApps": [],
        "favouriteClips": [],
        "favouriteEmojis": [],
        "hiddenApps": [],
        "maxShown": 7,
        "maxWallpapers": 9,
        "showOnHover": false,
        "specialPrefix": "@",
        "useFuzzy": {
            "actions": false,
            "apps": false,
            "clipboard": false,
            "emoji": false,
            "schemes": false,
            "variants": false,
            "wallpapers": false
        },
        "vimKeybinds": false
    },
    "lock": {
        "enabled": true,
        "useWallpaper": false,
        "enableFprint": true,
        "hideNotifs": false,
        "maxFprintTries": 3,
        "profilePicShape": 12,
        "recolourLogo": true,
        "enableHowdy": true,
        "maxHowdyTries": 3,
        "triggerHowdyOnWake": true
    },
    "nexus": {
        "networkRescanInterval": 15000,
        "wallpapersPerRow": 4
    },
    "notifs": {
        "actionOnClick": false,
        "clearThreshold": 0.3,
        "defaultExpireTimeout": 5000,
        "expandThreshold": 20,
        "expire": true,
        "fullscreen": "on",
        "fullscreenExpireTimeout": 2000,
        "groupPreviewNum": 3,
        "openExpanded": false
    },
    "osd": {
        "enableBrightness": true,
        "enableMicrophone": false,
        "enabled": true,
        "hideDelay": 2000
    },
    "paths": {
        "cacheDir": "/home/dim/.cache/caelestia",
        "lockNoNotifsPic": "root:/assets/dino.png",
        "lyricsDir": "/home/dim/Music/Lyrics/",
        "mediaGif": "root:/assets/bongocat.gif",
        "noNotifsPic": "root:/assets/dino.png",
        "sessionGif": "root:/assets/kurukuru.gif",
        "wallpaperDir": "/home/dim/Pictures/Wallpapers"
    },
    "services": {
        "audioIncrement": 0.1,
        "brightnessIncrement": 0.1,
        "defaultPlayer": "Spotify",
        "gpuType": "",
        "lyricsBackend": "Auto",
        "maxVolume": 1,
        "playerAliases": [
            {
                "from": "com.github.th_ch.youtube_music",
                "to": "YT Music"
            }
        ],
        "smartScheme": true,
        "useFahrenheit": true,
        "useFahrenheitPerformance": false,
        "useTwelveHourClock": true,
        "visualiserBars": 60,
        "weatherLocation": ""
    },
    "session": {
        "commands": {
            "hibernate": [
                "loginctl",
                "hibernate"
            ],
            "logout": [
                "hyprctl",
                "dispatch",
                "exit"
            ],
            "reboot": [
                "loginctl",
                "reboot"
            ],
            "shutdown": [
                "loginctl",
                "poweroff"
            ],
            "lock": [
                "loginctl",
                "lock-session"
            ]
        },
        "dragThreshold": 30,
        "enabled": true,
        "icons": {
            "hibernate": "downloading",
            "logout": "logout",
            "reboot": "cached",
            "shutdown": "power_settings_new",
            "lock": "lock"
        },
        "vimKeybinds": false
    },
    "shimeji": {
        "autoHide": true,
        "count": 1,
        "enabled": true,
        "excludedScreens": [],
        "path": "root:/assets/shimeji/pusheen/",
        "screenCounts": {}
    },
    "sidebar": {
        "enabled": true,
        "showOnHover": false,
        "minHoverThreshold": 200,
        "dragThreshold": 80
    },
    "utilities": {
        "enabled": true,
        "maxToasts": 4,
        "quickToggles": [
            {
                "enabled": true,
                "id": "wifi"
            },
            {
                "enabled": true,
                "id": "bluetooth"
            },
            {
                "enabled": true,
                "id": "quickshare"
            },
            {
                "enabled": true,
                "id": "mic"
            },
            {
                "enabled": true,
                "id": "settings"
            },
            {
                "enabled": true,
                "id": "gameMode"
            },
            {
                "enabled": true,
                "id": "dnd"
            },
            {
                "enabled": false,
                "id": "vpn"
            },
            {
                "enabled": true,
                "id": "wallpaper"
            },
            {
                "enabled": true,
                "id": "badapple"
            }
        ],
        "toasts": {
            "audioInputChanged": true,
            "audioOutputChanged": true,
            "capsLockChanged": true,
            "chargingChanged": true,
            "configLoaded": true,
            "dndChanged": true,
            "fullscreen": "off",
            "gameModeChanged": true,
            "kbLayoutChanged": true,
            "kbLimit": true,
            "nowPlaying": false,
            "numLockChanged": true,
            "transparency": false,
            "transparencyBase": 0.85,
            "vpnChanged": true
        },
        "vpn": {
            "enabled": false,
            "provider": []
        }
    },
    "winfo": {}
}
```

</details>

### Advanced configuration

> [!CAUTION]
> Do NOT change any of these options unless you know what you are doing. These options control the
> tokens used internally within the shell, and can cause visual issues if modified incorrectly.
> The available options may change or be removed without notice across versions.

A separate `~/.config/caelestia/shell-tokens.json` file allows editing the internal tokens without
touching the source code of the shell. These tokens affect the dimensions and appearance of visual elements,
including individual rounding, spacing, padding, font size, animation durations and curves, and the sizes of
certain components. The appearance scale values in `shell.json` are multiplied against these base
token values to produce the final computed values.

Per-monitor token overrides are also available at
`~/.config/caelestia/monitors/<monitor_name>/shell-tokens.json`.

### Home Manager Module

For NixOS users, a Home Manager module is also available.

<details><summary><code>home.nix</code></summary>

```nix
programs.caelestia = {
  enable = true;
  systemd = {
    enable = false; # if you prefer starting from your compositor
    target = "graphical-session.target";
    environment = [];
  };
  settings = {
    bar.statusIcons = [
      { id = "lockStatus"; enabled = true; }
      { id = "network"; enabled = true; }
      { id = "bluetooth"; enabled = true; }
      { id = "battery"; enabled = false; }
    ];
    paths.wallpaperDir = "~/Images";
  };
  cli = {
    enable = true; # Also add caelestia-cli to path
    settings = {
      theme.enableGtk = false;
    };
  };
};
```

The module automatically adds the shell to the path with **full functionality**. The CLI is not required; however, you can enable and configure it.

</details>

## FAQ

### Need help or support?

You can join the Caelestia Discord server for assistance and discussion [here][discord].

### The shell stutters or tears!

Try disabling VRR in the hyprland config. You can do this by adding the following to `~/.config/caelestia/hypr-user.conf`:

```conf
misc {
    vrr = 0
}
```

### How do I enable blur for the Polkit dialog?

Add the following layer rule to your `~/.config/caelestia/hypr-user.conf`:

```conf
layerrule = no_anim true, match:namespace caelestia-polkit, blur true, ignore_alpha 0.1
```

### I want to make my own changes to the hyprland config!

You can add your custom hyprland configs to `~/.config/caelestia/hypr-user.conf`.

### I want to make my own changes to other stuff!

See the [installation](#installation) section — the shell runs from a clone, so editing it
is editing the source.

### I want to disable ___ feature!

Most of what the two forks added is a flag under `hybrid.features` — see
[Features](#features), or open the Hybrid page in the settings app. Everything else is under
[configuring](#configuring). If there is no corresponding option, make a feature request.

### How do I make my colour scheme change to match my wallpaper?

Set a wallpaper via `>wallpaper` in the launcher or `caelestia wallpaper`, and set the scheme to the dynamic scheme via 
`>scheme` in the launcher or `caelestia scheme set`, e.g.:

```sh
caelestia wallpaper -f <path_to_wallpaper>
caelestia scheme set -n dynamic
```

### My wallpapers aren't showing up in the launcher!

The launcher pulls wallpapers from `~/Pictures/Wallpapers` by default. You can change this in the config. Additionally,
the launcher only shows an odd number of wallpapers at one time. If you only have 2 wallpapers, consider getting more
(or just putting one).

## Credits

This shell is a merge of three GPL-3.0 projects, and everything below the hybrid layer is
their work:

-   [caelestia-dots/shell](https://github.com/caelestia-dots/shell) — the upstream this
    tracks. Merged, never rebased onto.
-   [dim-ghub/midnight-shell](https://github.com/dim-ghub/midnight-shell) — the baseline.
    The launchers, the wallpaper engine, the bar work, the clipboard and emoji pickers,
    QuickShare, the games, and most of what is listed under Features.
-   [OVERxPOWERED/op-caelestia-shell](https://github.com/OVERxPOWERED/op-caelestia-shell) —
    the overview, the dock, the theme manager, the hotspot and Bluetooth agent work.

`hybrid/docs/provenance.md` records which files came from where, file by file.

Thanks to the Hyprland Discord community (especially the homies in #rice-discussion) for all the help and suggestions
for improving these dots!

A special thanks to [@outfoxxed](https://github.com/outfoxxed) for making Quickshell and the effort put into fixing issues
and implementing various feature requests.

Another special thanks to [@end_4](https://github.com/end-4) for his [config](https://github.com/end-4/dots-hyprland)
which helped me a lot with learning how to use Quickshell.

Finally, another thank you to all the configs I took inspiration from (only one for now):

-   [Axenide/Ax-Shell](https://github.com/Axenide/Ax-Shell)

[dots-repo]: https://github.com/caelestia-dots/caelestia
[discord]: https://caelestiashell.com/discord