import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<string> positionValues: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    readonly property list<MenuItem> positionItems: [
        MenuItem {
            text: qsTr("Top Left")
        },
        MenuItem {
            text: qsTr("Top Center")
        },
        MenuItem {
            text: qsTr("Top Right")
        },
        MenuItem {
            text: qsTr("Middle Left")
        },
        MenuItem {
            text: qsTr("Middle Center")
        },
        MenuItem {
            text: qsTr("Middle Right")
        },
        MenuItem {
            text: qsTr("Bottom Left")
        },
        MenuItem {
            text: qsTr("Bottom Center")
        },
        MenuItem {
            text: qsTr("Bottom Right")
        }
    ]

    title: qsTr("Desktop clock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            last: true
            Layout.fillWidth: true
            text: qsTr("Enable desktop clock")
            configNode: root.targetConfig.background.desktopClock
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopClock.enabled
            onToggled: {
                root.targetConfig.background.desktopClock.enabled = checked;
            }
        }

        SectionHeader {
            text: qsTr("Appearance")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Position")
            configNode: root.targetConfig.background.desktopClock
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[root.positionValues.indexOf(root.targetConfig.background.desktopClock.position)] ?? root.positionItems[4]
            onSelected: item => {
                let idx = root.positionItems.indexOf(item);
                if (idx !== -1) {
                    root.targetConfig.background.desktopClock.position = root.positionValues[idx];
                }
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Scale")
            configNode: root.targetConfig.background.desktopClock
            propertyName: "scale"
            value: (root.targetConfig.background.desktopClock.scale - 0.5) / 2.5
            valueLabel: (0.5 + value * 2.5).toFixed(1) + "x"
            onMoved: v => {
                root.targetConfig.background.desktopClock.scale = 0.5 + v * 2.5;
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Invert colors")
            subtext: qsTr("Invert the clock color when using light wallpaper")
            configNode: root.targetConfig.background.desktopClock
            propertyName: "invertColors"
            checked: root.targetConfig.background.desktopClock.invertColors
            onToggled: {
                root.targetConfig.background.desktopClock.invertColors = checked;
            }
        }

        SectionHeader {
            text: qsTr("Background")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable background")
            configNode: root.targetConfig.background.desktopClock.background
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopClock.background.enabled
            onToggled: {
                root.targetConfig.background.desktopClock.background.enabled = checked;
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.targetConfig.background.desktopClock.background
            propertyName: "opacity"
            value: root.targetConfig.background.desktopClock.background.opacity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.targetConfig.background.desktopClock.background.opacity = v;
            }
            enabled: root.targetConfig.background.desktopClock.background.enabled
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Blur")
            configNode: root.targetConfig.background.desktopClock.background
            propertyName: "blur"
            checked: root.targetConfig.background.desktopClock.background.blur
            onToggled: {
                root.targetConfig.background.desktopClock.background.blur = checked;
            }
            enabled: root.targetConfig.background.desktopClock.background.enabled
        }

        SectionHeader {
            text: qsTr("Shadow")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable shadow")
            configNode: root.targetConfig.background.desktopClock.shadow
            propertyName: "enabled"
            checked: root.targetConfig.background.desktopClock.shadow.enabled
            onToggled: {
                root.targetConfig.background.desktopClock.shadow.enabled = checked;
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.targetConfig.background.desktopClock.shadow
            propertyName: "opacity"
            value: root.targetConfig.background.desktopClock.shadow.opacity
            valueLabel: Math.round(value * 100) + "%"
            onMoved: v => {
                root.targetConfig.background.desktopClock.shadow.opacity = v;
            }
            enabled: root.targetConfig.background.desktopClock.shadow.enabled
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Blur strength")
            configNode: root.targetConfig.background.desktopClock.shadow
            propertyName: "blur"
            value: root.targetConfig.background.desktopClock.shadow.blur / 2.0
            valueLabel: (value * 2.0).toFixed(1)
            onMoved: v => {
                root.targetConfig.background.desktopClock.shadow.blur = v * 2.0;
            }
            enabled: root.targetConfig.background.desktopClock.shadow.enabled
        }
    }
}
