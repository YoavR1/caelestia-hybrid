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

    // Ordered to match config::HybridVariant (Midnight, Op).
    readonly property list<MenuItem> variantItems: [
        MenuItem {
            text: "MiDnight"
        },
        MenuItem {
            text: "OP"
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
            configNode: root.targetConfig.hybrid
            propertyName: "preset"
            menuItems: root.presetItems
            active: root.presetItems[root.targetConfig.hybrid.preset]
            onSelected: item => {
                root.targetConfig.hybrid.preset = root.presetItems.indexOf(item);
            }
        }

        // ------------------------------------------------------------ from OP

        SectionHeader {
            text: qsTr("From OP-Caelestia")
        }

        ToggleRow {
            first: true
            text: qsTr("Dock")
            subtext: qsTr("A separate dock window with pinned and running apps")
            configNode: root.targetConfig.hybrid.features
            propertyName: "dock"
            checked: root.targetConfig.hybrid.features.dock
            onToggled: root.targetConfig.hybrid.features.dock = checked
        }

        ToggleRow {
            text: qsTr("Overview")
            subtext: qsTr("Workspace overview with window thumbnails")
            configNode: root.targetConfig.hybrid.features
            propertyName: "overview"
            checked: root.targetConfig.hybrid.features.overview
            onToggled: root.targetConfig.hybrid.features.overview = checked
        }

        ToggleRow {
            text: qsTr("Hotspot")
            subtext: qsTr("Share this machine's connection over Wi-Fi")
            configNode: root.targetConfig.hybrid.features
            propertyName: "hotspot"
            checked: root.targetConfig.hybrid.features.hotspot
            onToggled: root.targetConfig.hybrid.features.hotspot = checked
        }

        ToggleRow {
            text: qsTr("GPU detection")
            subtext: qsTr("Detect the GPU vendor instead of assuming one")
            configNode: root.targetConfig.hybrid.features
            propertyName: "gpuDetection"
            checked: root.targetConfig.hybrid.features.gpuDetection
            onToggled: root.targetConfig.hybrid.features.gpuDetection = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Theme manager")
            subtext: qsTr("Switch GTK and Qt themes from the shell")
            configNode: root.targetConfig.hybrid.features
            propertyName: "themeManager"
            checked: root.targetConfig.hybrid.features.themeManager
            onToggled: root.targetConfig.hybrid.features.themeManager = checked
        }

        // ------------------------------------------------------ from MiDnight

        SectionHeader {
            text: qsTr("From MiDnight")
        }

        ToggleRow {
            first: true
            text: qsTr("Clipboard history")
            subtext: qsTr("Search and paste from the launcher")
            configNode: root.targetConfig.hybrid.features
            propertyName: "clipboard"
            checked: root.targetConfig.hybrid.features.clipboard
            onToggled: root.targetConfig.hybrid.features.clipboard = checked
        }

        ToggleRow {
            text: qsTr("Emoji picker")
            subtext: qsTr("Search emoji from the launcher")
            configNode: root.targetConfig.hybrid.features
            propertyName: "emojiPicker"
            checked: root.targetConfig.hybrid.features.emojiPicker
            onToggled: root.targetConfig.hybrid.features.emojiPicker = checked
        }

        ToggleRow {
            text: qsTr("Window switcher")
            subtext: qsTr("Switch windows from the launcher")
            configNode: root.targetConfig.hybrid.features
            propertyName: "windowSwitcher"
            checked: root.targetConfig.hybrid.features.windowSwitcher
            onToggled: root.targetConfig.hybrid.features.windowSwitcher = checked
        }

        ToggleRow {
            text: qsTr("Keybind viewer")
            subtext: qsTr("Browse Hyprland keybinds from the launcher")
            configNode: root.targetConfig.hybrid.features
            propertyName: "keybindViewer"
            checked: root.targetConfig.hybrid.features.keybindViewer
            onToggled: root.targetConfig.hybrid.features.keybindViewer = checked
        }

        ToggleRow {
            text: qsTr("Video wallpapers")
            subtext: qsTr("Animated wallpapers, paused when nothing can see them")
            configNode: root.targetConfig.hybrid.features
            propertyName: "videoWallpaper"
            checked: root.targetConfig.hybrid.features.videoWallpaper
            onToggled: root.targetConfig.hybrid.features.videoWallpaper = checked
        }

        ToggleRow {
            text: qsTr("Wallhaven")
            subtext: qsTr("Browse and set wallpapers from wallhaven.cc")
            configNode: root.targetConfig.hybrid.features
            propertyName: "wallhaven"
            checked: root.targetConfig.hybrid.features.wallhaven
            onToggled: root.targetConfig.hybrid.features.wallhaven = checked
        }

        ToggleRow {
            text: qsTr("Floating lyrics")
            subtext: qsTr("Show synced lyrics on the desktop")
            configNode: root.targetConfig.hybrid.features
            propertyName: "floatingLyrics"
            checked: root.targetConfig.hybrid.features.floatingLyrics
            onToggled: root.targetConfig.hybrid.features.floatingLyrics = checked
        }

        SectionHeader {
            text: qsTr("For fun")
        }

        ToggleRow {
            first: true
            text: qsTr("Shimeji")
            subtext: qsTr("Desktop pets that wander across your screens")
            configNode: root.targetConfig.hybrid.features
            propertyName: "shimeji"
            checked: root.targetConfig.hybrid.features.shimeji
            onToggled: root.targetConfig.hybrid.features.shimeji = checked
        }

        ToggleRow {
            text: qsTr("Bad Apple")
            subtext: qsTr("You know what this is")
            configNode: root.targetConfig.hybrid.features
            propertyName: "badApple"
            checked: root.targetConfig.hybrid.features.badApple
            onToggled: root.targetConfig.hybrid.features.badApple = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Dino game")
            subtext: qsTr("The Chrome runner, in the notification dock")
            configNode: root.targetConfig.hybrid.features
            propertyName: "dino"
            checked: root.targetConfig.hybrid.features.dino
            onToggled: root.targetConfig.hybrid.features.dino = checked
        }

        // ---------------------------------------------------------- variants

        SectionHeader {
            text: qsTr("Variants")
        }

        SelectRow {
            first: true
            label: qsTr("Lock centre")
            subtext: qsTr("Which fork's lock screen layout to use")
            configNode: root.targetConfig.hybrid.variants
            propertyName: "lockCentre"
            menuItems: root.variantItems
            active: root.variantItems[root.targetConfig.hybrid.variants.lockCentre]
            onSelected: item => {
                root.targetConfig.hybrid.variants.lockCentre = root.variantItems.indexOf(item);
            }
        }

        SelectRow {
            label: qsTr("Audio popout")
            subtext: qsTr("Which fork's audio panel to use")
            configNode: root.targetConfig.hybrid.variants
            propertyName: "audioPopout"
            menuItems: root.variantItems
            active: root.variantItems[root.targetConfig.hybrid.variants.audioPopout]
            onSelected: item => {
                root.targetConfig.hybrid.variants.audioPopout = root.variantItems.indexOf(item);
            }
        }

        SelectRow {
            label: qsTr("Desktop clock")
            subtext: qsTr("Which fork's desktop clock to use")
            configNode: root.targetConfig.hybrid.variants
            propertyName: "desktopClock"
            menuItems: root.variantItems
            active: root.variantItems[root.targetConfig.hybrid.variants.desktopClock]
            onSelected: item => {
                root.targetConfig.hybrid.variants.desktopClock = root.variantItems.indexOf(item);
            }
        }

        SelectRow {
            last: true
            label: qsTr("Colour scheme engine")
            subtext: qsTr("Which fork's scheme generation to use")
            configNode: root.targetConfig.hybrid.variants
            propertyName: "colours"
            menuItems: root.variantItems
            active: root.variantItems[root.targetConfig.hybrid.variants.colours]
            onSelected: item => {
                root.targetConfig.hybrid.variants.colours = root.variantItems.indexOf(item);
            }
        }
    }
}
