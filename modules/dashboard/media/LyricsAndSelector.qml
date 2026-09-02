import "../dash" as DashTab
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.bottomMargin: -Tokens.spacing.medium
            spacing: Tokens.spacing.medium
            visible: !Config.dashboard.replaceMediaLyricsWithVisuals
            z: 1

            MaterialIcon {
                Layout.topMargin: Math.round(fontInfo.pointSize * 0.12)
                text: "lyrics"
                fontStyle: Tokens.font.icon.medium
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Lyrics")
                font: Tokens.font.title.medium
            }

            LyricsInfo {}
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true

            sourceComponent: Config.dashboard.replaceMediaLyricsWithVisuals ? visualComp : lyricComp
        }

        Component {
            id: lyricComp

            LyricList { }
        }

        Component {
            id: visualComp

            Item {
                anchors.fill: parent

                AnimatedImage {
                    id: gif

                    anchors.fill: parent

                    playing: Players.active?.isPlaying ?? false
                    speed: Audio.beatTracker.bpm / Config.general.mediaGifSpeedAdjustment // qmllint disable unresolved-type
                    source: Paths.absolutePath(Config.paths.mediaGif)
                    asynchronous: true
                    fillMode: AnimatedImage.PreserveAspectFit
                    visible: !Config.dashboard.useMediaShapes
                }

                MultiEffect {
                    anchors.fill: gif
                    source: gif

                    visible: Config.dashboard.colorizeMediaGif && !Config.dashboard.useMediaShapes
                    colorization: 1
                    colorizationColor: Colours.palette.m3primary
                }

                DashTab.MediaShapes {
                    anchors.fill: parent
                    visible: Config.dashboard.useMediaShapes
                }
            }
        }

        SplitButton {
            Layout.alignment: Qt.AlignHCenter

            type: SplitButton.Tonal
            disabled: !Players.list.length
            active: menuItems.find(m => m.modelData === Players.active) ?? menuItems[0] ?? null
            menu.onItemSelected: item => Players.manualActive = (item as PlayerItem).modelData

            menuItems: playerList.instances
            fallbackIcon: "music_off"
            fallbackText: qsTr("No players")

            minLeftWidth: layout.width - expandBtn.implicitWidth - spacing
            label.Layout.maximumWidth: minLeftWidth - iconLabel.implicitWidth - textRow.spacing - textRow.anchors.horizontalCenterOffset / 2 - horizontalPadding * 2
            label.elide: Text.ElideRight

            stateLayer.disabled: true
            menuOnTop: true

            Variants {
                id: playerList

                model: Players.list

                PlayerItem {}
            }
        }
    }

    component PlayerItem: MenuItem {
        required property MprisPlayer modelData

        icon: modelData === Players.active ? "check" : ""
        text: Players.getIdentity(modelData)
        activeIcon: "animated_images"
    }
}
