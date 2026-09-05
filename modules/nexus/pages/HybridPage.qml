import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    // Ordered to match config::HybridPreset (Recommended, Midnight, Op).
    readonly property list<MenuItem> presetItems: [
        MenuItem {
            text: qsTr("Recommended")
            icon: "recommend"
        },
        MenuItem {
            text: "MiDnight"
            icon: "dark_mode"
        },
        MenuItem {
            text: "OP"
            icon: "bolt"
        }
    ]

    // Ordered to match config::HybridVariant (Midnight, Op). Indexed by ordinal, so a new
    // enumerator must be appended in both places -- see T47.
    readonly property list<MenuItem> variantItems: [
        MenuItem {
            text: qsTr("MiDnight")
        },
        MenuItem {
            text: qsTr("OP")
        }
    ]

    title: qsTr("Hybrid")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Preset")
        }

        SelectRow {
            first: true
            last: true
            label: qsTr("Preset")
            subtext: qsTr("A starting set of features. Anything you change below stays changed.")
            configNode: GlobalConfig.hybrid
            propertyName: "preset"
            menuItems: root.presetItems
            active: root.presetItems[GlobalConfig.hybrid.preset]
            onSelected: item => {
                GlobalConfig.hybrid.preset = root.presetItems.indexOf(item);
            }
        }

        // ------------------------------------------------------------- panels

        SectionHeader {
            text: qsTr("Panels")
        }

        ToggleRow {
            first: true
            text: qsTr("Dock")
            subtext: qsTr("A separate dock window with pinned and running apps")
            configNode: GlobalConfig.hybrid.features
            propertyName: "dock"
            checked: GlobalConfig.hybrid.features.dock
            onToggled: GlobalConfig.hybrid.features.dock = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Overview")
            subtext: qsTr("Workspace overview with window thumbnails")
            configNode: GlobalConfig.hybrid.features
            propertyName: "overview"
            checked: GlobalConfig.hybrid.features.overview
            onToggled: GlobalConfig.hybrid.features.overview = checked
        }

        // ------------------------------------------------------------ launcher

        SectionHeader {
            text: qsTr("Launcher")
        }

        ToggleRow {
            first: true
            text: qsTr("Clipboard history")
            subtext: qsTr("Search and paste from the launcher")
            configNode: GlobalConfig.hybrid.features
            propertyName: "clipboard"
            checked: GlobalConfig.hybrid.features.clipboard
            onToggled: GlobalConfig.hybrid.features.clipboard = checked
        }

        ToggleRow {
            text: qsTr("Emoji picker")
            subtext: qsTr("Search emoji from the launcher")
            configNode: GlobalConfig.hybrid.features
            propertyName: "emojiPicker"
            checked: GlobalConfig.hybrid.features.emojiPicker
            onToggled: GlobalConfig.hybrid.features.emojiPicker = checked
        }

        ToggleRow {
            text: qsTr("Window switcher")
            subtext: qsTr("Switch windows from the launcher")
            configNode: GlobalConfig.hybrid.features
            propertyName: "windowSwitcher"
            checked: GlobalConfig.hybrid.features.windowSwitcher
            onToggled: GlobalConfig.hybrid.features.windowSwitcher = checked
        }

        ToggleRow {
            text: qsTr("Keybind viewer")
            subtext: qsTr("Browse Hyprland keybinds from the launcher")
            configNode: GlobalConfig.hybrid.features
            propertyName: "keybindViewer"
            checked: GlobalConfig.hybrid.features.keybindViewer
            onToggled: GlobalConfig.hybrid.features.keybindViewer = checked
        }

        ToggleRow {
            text: qsTr("Video wallpapers")
            subtext: qsTr("Animated wallpapers, paused when nothing can see them")
            configNode: GlobalConfig.hybrid.features
            propertyName: "videoWallpaper"
            checked: GlobalConfig.hybrid.features.videoWallpaper
            onToggled: GlobalConfig.hybrid.features.videoWallpaper = checked
        }

        ToggleRow {
            text: qsTr("Wallhaven")
            subtext: qsTr("Browse and set wallpapers from wallhaven.cc")
            configNode: GlobalConfig.hybrid.features
            propertyName: "wallhaven"
            checked: GlobalConfig.hybrid.features.wallhaven
            onToggled: GlobalConfig.hybrid.features.wallhaven = checked
        }

        ToggleRow {
            text: qsTr("Floating lyrics")
            subtext: qsTr("Show synced lyrics on the desktop")
            configNode: GlobalConfig.hybrid.features
            propertyName: "floatingLyrics"
            checked: GlobalConfig.hybrid.features.floatingLyrics
            onToggled: GlobalConfig.hybrid.features.floatingLyrics = checked
        }

        ToggleRow {
            text: qsTr("Theme packs")
            subtext: qsTr("Swap wallpaper and shell artwork as a named set")
            configNode: GlobalConfig.hybrid.features
            propertyName: "themeManager"
            checked: GlobalConfig.hybrid.features.themeManager
            onToggled: GlobalConfig.hybrid.features.themeManager = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Confirm power actions on the lock screen")
            subtext: qsTr("Ask before shutdown, reboot or logout from the lock screen")
            configNode: GlobalConfig.hybrid.features
            propertyName: "lockPowerConfirm"
            checked: GlobalConfig.hybrid.features.lockPowerConfirm
            onToggled: GlobalConfig.hybrid.features.lockPowerConfirm = checked
        }

        SectionHeader {
            text: qsTr("Network")
        }

        ToggleRow {
            first: true
            text: qsTr("Hotspot")
            subtext: qsTr("Share this machine's connection as a Wi-Fi access point")
            configNode: GlobalConfig.hybrid.features
            propertyName: "hotspot"
            checked: GlobalConfig.hybrid.features.hotspot
            onToggled: GlobalConfig.hybrid.features.hotspot = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Bluetooth pairing agent")
            subtext: qsTr("Answer pairing requests from other devices. Takes effect on restart")
            configNode: GlobalConfig.hybrid.features
            propertyName: "btAgent"
            checked: GlobalConfig.hybrid.features.btAgent
            onToggled: GlobalConfig.hybrid.features.btAgent = checked
        }

        SectionHeader {
            text: qsTr("For fun")
        }

        ToggleRow {
            first: true
            text: qsTr("Shimeji")
            subtext: qsTr("Desktop pets that wander across your screens")
            configNode: GlobalConfig.hybrid.features
            propertyName: "shimeji"
            checked: GlobalConfig.hybrid.features.shimeji
            onToggled: GlobalConfig.hybrid.features.shimeji = checked
        }

        ToggleRow {
            text: qsTr("Bad Apple")
            subtext: qsTr("You know what this is")
            configNode: GlobalConfig.hybrid.features
            propertyName: "badApple"
            checked: GlobalConfig.hybrid.features.badApple
            onToggled: GlobalConfig.hybrid.features.badApple = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Dino game")
            subtext: qsTr("The Chrome runner, in the notification dock")
            configNode: GlobalConfig.hybrid.features
            propertyName: "dino"
            checked: GlobalConfig.hybrid.features.dino
            onToggled: GlobalConfig.hybrid.features.dino = checked
        }

        // ------------------------------------------------------------ variants

        SectionHeader {
            text: qsTr("Variants")
        }

        // Only sites that genuinely have two implementations appear here. A selector for one
        // that does not would visibly do nothing, which is worse than its absence.
        //
        // `desktopClock` and `colours` were declared alongside these and are now gone. OP's
        // DesktopClock.qml is byte-identical to upstream's, so there was never a second clock
        // to select between, and its Colours.qml change is +52/-2 on a *service*, which D5 says
        // is merged rather than dual-implemented. `lockCentre` is still declared and still
        // absent here, because OP genuinely has a second one -- but its PasswordInput refers to
        // PatternGrid eight times, so importing it means importing the lock-screen bypass that
        // D10 and T3 block. It waits on Phase 8.
        SelectRow {
            first: true
            label: qsTr("Audio popout")
            subtext: qsTr("Which fork's audio panel the bar opens")
            configNode: GlobalConfig.hybrid.variants
            propertyName: "audioPopout"
            menuItems: root.variantItems
            active: root.variantItems[GlobalConfig.hybrid.variants.audioPopout === HybridVariant.Op ? 1 : 0]
            onSelected: item => {
                GlobalConfig.hybrid.variants.audioPopout = root.variantItems.indexOf(item) === 1 ? HybridVariant.Op : HybridVariant.Midnight;
            }
        }

        SelectRow {
            label: qsTr("Workspace overview")
            subtext: qsTr("MiDnight's drawer, or OP's carousel and window grid")
            configNode: GlobalConfig.hybrid.variants
            propertyName: "overview"
            menuItems: root.variantItems
            active: root.variantItems[GlobalConfig.hybrid.variants.overview === HybridVariant.Op ? 1 : 0]
            onSelected: item => {
                GlobalConfig.hybrid.variants.overview = root.variantItems.indexOf(item) === 1 ? HybridVariant.Op : HybridVariant.Midnight;
            }
        }

        SelectRow {
            last: true
            label: qsTr("Dock")
            subtext: qsTr("MiDnight's bar section, or OP's auto-hiding panel")
            configNode: GlobalConfig.hybrid.variants
            propertyName: "dock"
            menuItems: root.variantItems
            active: root.variantItems[GlobalConfig.hybrid.variants.dock === HybridVariant.Op ? 1 : 0]
            onSelected: item => {
                GlobalConfig.hybrid.variants.dock = root.variantItems.indexOf(item) === 1 ? HybridVariant.Op : HybridVariant.Midnight;
            }
        }
    }
}
