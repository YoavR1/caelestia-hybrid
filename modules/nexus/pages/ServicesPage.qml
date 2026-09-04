import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Lyrics backends, ordered to match config::LyricsBackend (Auto, Local, LRCLIB, NetEase)
    readonly property list<MenuItem> lyricsItems: [
        MenuItem {
            text: qsTr("Auto")
        },
        MenuItem {
            text: "Local"
        },
        MenuItem {
            text: "LRCLIB"
        },
        MenuItem {
            text: "NetEase"
        }
    ]

    // GPU types, ordered to match config::GpuType (Auto, Nvidia, Generic, None, Intel).
    // Indexed by ordinal, so a new enumerator must be appended in both places or every entry
    // after the insertion point silently labels the wrong type.
    readonly property list<MenuItem> gpuItems: [
        MenuItem {
            text: qsTr("Auto")
        },
        MenuItem {
            text: "NVIDIA"
        },
        MenuItem {
            text: qsTr("Generic")
        },
        MenuItem {
            text: qsTr("None")
        },
        MenuItem {
            text: "Intel"
        }
    ]

    title: qsTr("Services")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Detected running players, used as default-player options
        Variants {
            id: playerVariants

            model: [...new Set(Players.list.map(p => Players.getIdentity(p)).filter(id => id))]

            MenuItem {
                required property string modelData

                text: modelData
                icon: modelData === GlobalConfig.services.defaultPlayer ? "check" : ""
                activeIcon: "music_note"
            }
        }

        // Notifications
        SectionHeader {
            first: true
            text: qsTr("Notifications")
        }

        NavRow {
            first: true
            last: true
            icon: "notifications"
            text: qsTr("Notifications")
            subtext: qsTr("Notifications, toasts, timeouts")
            onClicked: root.nState.openSubPage(1)
        }

        // Connections
        SectionHeader {
            text: qsTr("Polling")
        }

        StepperRow {
            first: true
            label: qsTr("Media refresh")
            subtext: qsTr("How often the media position updates (ms)")
            value: GlobalConfig.dashboard.mediaUpdateInterval
            from: 100
            to: 2000
            stepSize: 50
            onMoved: v => GlobalConfig.dashboard.mediaUpdateInterval = v
        }

        StepperRow {
            label: qsTr("System stats refresh")
            subtext: qsTr("CPU, memory and GPU update interval (seconds)")
            value: GlobalConfig.dashboard.resourceUpdateInterval / 1000
            from: 0.5
            to: 10
            stepSize: 0.5
            onMoved: v => GlobalConfig.dashboard.resourceUpdateInterval = Math.round(v * 1000)
        }

        StepperRow {
            last: true
            label: qsTr("Wi-Fi rescan")
            subtext: qsTr("How often available networks are rescanned (seconds)")
            value: GlobalConfig.nexus.networkRescanInterval / 1000
            from: 5
            to: 120
            stepSize: 5
            onMoved: v => GlobalConfig.nexus.networkRescanInterval = Math.round(v * 1000)
        }

        // Media & lyrics
        SectionHeader {
            text: qsTr("Media & lyrics")
        }

        SelectRow {
            first: true
            label: qsTr("Lyrics backend")
            subtext: qsTr("Source used to fetch synced lyrics")
            menuItems: root.lyricsItems
            active: root.lyricsItems[Lyrics.preferredBackend] ?? root.lyricsItems[0]
            onSelected: item => Lyrics.preferredBackend = root.lyricsItems.indexOf(item)
        }

        SelectRow {
            last: true
            label: qsTr("Default player")
            subtext: qsTr("Preferred media player when several are open")
            menuItems: playerVariants.instances
            active: menuItems.find(i => i.text === GlobalConfig.services.defaultPlayer) ?? null
            fallbackIcon: "music_note"
            fallbackText: GlobalConfig.services.defaultPlayer || qsTr("Auto")
            onSelected: item => GlobalConfig.services.defaultPlayer = item.text
        }

        // Input increments
        SectionHeader {
            text: qsTr("Input increments")
        }

        StepperRow {
            first: true
            label: qsTr("Volume step")
            subtext: qsTr("Amount the volume changes per scroll (%)")
            value: Math.round(GlobalConfig.services.audioIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.audioIncrement = v / 100
        }

        StepperRow {
            label: qsTr("Brightness step")
            subtext: qsTr("Amount the brightness changes per scroll (%)")
            value: Math.round(GlobalConfig.services.brightnessIncrement * 100)
            from: 1
            to: 50
            stepSize: 1
            onMoved: v => GlobalConfig.services.brightnessIncrement = v / 100
        }

        StepperRow {
            last: true
            label: qsTr("Max volume")
            subtext: qsTr("Upper limit for output volume (%)")
            value: Math.round(GlobalConfig.services.maxVolume * 100)
            from: 50
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.services.maxVolume = v / 100
        }

        // Service tuning
        SectionHeader {
            text: qsTr("Service tuning")
        }

        NavRow {
            first: true
            icon: "sports_esports"
            text: qsTr("Game mode")
            subtext: qsTr("Manage how MiDnight behaves while gaming")
            onClicked: root.nState.openSubPage(2)
        }

        NavRow {
            icon: "chat" // Using chat since discord icon might not be available in Material icons
            text: qsTr("Discord Rich Presence")
            subtext: qsTr("Broadcast your status to Vesktop")
            onClicked: root.nState.openSubPage(4)
        }

        NavRow {
            icon: "picture_in_picture"
            text: qsTr("Picture in Picture")
            subtext: qsTr("Configure PiP positioning and focus behavior")
            onClicked: root.nState.openSubPage(5)
        }

        NavRow {
            icon: "near_me"
            text: qsTr("Quick Share")
            subtext: qsTr("Auto-start and discoverability settings")
            onClicked: root.nState.openSubPage(6)
        }

        SelectRow {
            Layout.fillWidth: true
            last: true
            label: qsTr("GPU")
            subtext: Gpu.name ? qsTr("Monitoring: %1").arg(Gpu.name) : qsTr("Override for GPU type")
            menuOnTop: true
            menuItems: root.gpuItems
            active: root.gpuItems[GlobalConfig.services.gpuType]
            onSelected: item => GlobalConfig.services.gpuType = root.gpuItems.indexOf(item)
        }
    }
}
