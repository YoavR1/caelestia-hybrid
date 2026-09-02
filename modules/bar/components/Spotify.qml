pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

StyledRect {
    id: root

    required property var popouts

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"
    readonly property MprisPlayer player: Players.active

    readonly property int maxLen: Config.bar.spotify.maxTitleLength
    readonly property string rawTitle: player?.trackTitle || qsTr("Spotify")
    readonly property string trackTitle: rawTitle.length > maxLen ? rawTitle.substring(0, maxLen) + "…" : rawTitle
    readonly property bool isPlaying: player?.isPlaying ?? false

    implicitWidth: isHorizontal ? contentLayout.implicitWidth + Tokens.padding.medium * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : contentLayout.implicitHeight + Tokens.padding.medium * 2

    color: Config.bar.spotify.background ? Colours.tPalette.m3surfaceContainer : Qt.alpha(Colours.tPalette.m3surfaceContainer, 0)
    radius: Tokens.rounding.full

    ServiceRef {
        service: Config.bar.spotify.showVisualiser ? Audio.cava : null
    }

    GridLayout {
        id: contentLayout

        anchors.centerIn: parent
        columns: root.isHorizontal ? 2 : 1
        rows: root.isHorizontal ? 1 : 2
        rowSpacing: Tokens.spacing.small
        columnSpacing: Tokens.spacing.small

        Item {
            id: textContainer

            Layout.alignment: Qt.AlignCenter
            Layout.row: root.isHorizontal ? 0 : (Config.bar.spotify.inverted ? 1 : 0)
            Layout.column: 0

            implicitWidth: root.isHorizontal ? titleText.implicitWidth : titleText.implicitHeight
            implicitHeight: root.isHorizontal ? titleText.implicitHeight : titleText.implicitWidth

            StyledText {
                id: titleText

                anchors.centerIn: parent
                text: root.trackTitle
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
                animate: true

                rotation: root.isHorizontal ? 0 : (Config.bar.spotify.inverted ? 270 : 90)
            }
        }

        Item {
            id: equalizerContainer

            Layout.alignment: Qt.AlignCenter
            Layout.row: root.isHorizontal ? 0 : (Config.bar.spotify.inverted ? 0 : 1)
            Layout.column: root.isHorizontal ? 1 : 0

            visible: Config.bar.spotify.showVisualiser
            implicitWidth: root.isHorizontal ? (visible ? 23 : 0) : 20
            implicitHeight: root.isHorizontal ? 20 : (visible ? 23 : 0)

            Item {
                anchors.centerIn: parent
                width: 23
                height: 20

                rotation: root.isHorizontal ? 0 : (Config.bar.spotify.inverted ? 270 : 90)

                Repeater {
                    model: 5

                    Rectangle {
                        id: barItem

                        required property int index

                        readonly property real cavaVal: (Audio.cava && Audio.cava.values && Audio.cava.values.length > index * 2) ? Audio.cava.values[index * 2] : 0
                        readonly property real rawHeight: root.isPlaying ? Math.max(3, Math.min(18, 3 + cavaVal * 15)) : 3

                        property real animHeight: 3

                        x: index * 5

                        width: 3

                        height: Math.round(animHeight)

                        y: Math.round((20 - height) / 2)

                        radius: 1.5

                        color: Colours.palette.m3primary

                        Behavior on animHeight {
                            NumberAnimation {
                                duration: 50
                                easing.type: Easing.OutQuad
                            }
                        }

                        Binding {
                            target: barItem
                            property: "animHeight"
                            value: barItem.rawHeight
                        }
                    }
                }
            }
        }
    }
}
