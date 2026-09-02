pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services

ColumnLayout {
    id: root

    required property PopoutState popouts

    readonly property MprisPlayer player: Players.active
    readonly property bool hasUnknownLength: (player?.length ?? 0) > 2147483647

    readonly property PwNode playerStream: Audio.streams.find(s => {
        const identity = root.player?.identity?.toLowerCase() ?? "";
        const entry = (root.player?.entry ?? "").toString().toLowerCase();
        if (!identity && !entry)
            return false;
        const streamName = Audio.getStreamName(s).toLowerCase();
        const binary = (s.properties["application.process.binary"] ?? "").toString().toLowerCase();
        const appName = (s.properties["app.name"] ?? "").toString().toLowerCase();
        const playerNames = [identity, entry].filter(n => n);
        const streamNames = [streamName, binary, appName].filter(n => n);
        return streamNames.some(sn => playerNames.some(pn => sn.includes(pn) || pn.includes(sn)));
    }) || null
    readonly property real currentVolume: (Players.supportsAppVolume(root.player) && typeof root.player?.volume !== "undefined" && root.player?.volume !== null) ? root.player.volume : (root.playerStream ? Audio.getStreamVolume(root.playerStream) : Audio.volume)

    readonly property bool isHorizontalVolume: Config.bar.spotify.horizontalVolume

    function setSpotifyVolume(v: real): void {
        const clamped = Math.max(0, Math.min(1, v));
        if (Players.supportsAppVolume(root.player) && root.player && typeof root.player.volume !== "undefined") {
            root.player.volume = clamped;
        } else if (root.playerStream) {
            Audio.setStreamVolume(root.playerStream, clamped);
        } else {
            Audio.setVolume(clamped);
        }
    }

    function lengthStr(length: int): string {
        if (length < 0)
            return "-1:-1";

        const hours = Math.floor(length / 3600);
        const mins = Math.floor((length % 3600) / 60);
        const secs = Math.floor(length % 60).toString().padStart(2, "0");

        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    width: root.isHorizontalVolume ? 235 : 275
    spacing: Tokens.spacing.small

    Timer {
        running: root.player?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Item {
            id: coverContainer

            Layout.preferredWidth: root.isHorizontalVolume ? 235 : 225
            Layout.preferredHeight: root.isHorizontalVolume ? 235 : 225

            Item {
                id: maskWrapper

                anchors.fill: parent
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "black"
                }
            }

            StyledRect {
                anchors.fill: parent
                radius: Tokens.rounding.medium
                color: Colours.palette.m3surfaceContainerHighest

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    fontStyle: Tokens.font.icon.size(64).build()
                    color: Colours.palette.m3onSurfaceVariant
                    visible: !Players.getArtUrl(root.player)
                }
            }

            FadeImage {
                id: coverImage

                anchors.fill: parent
                source: Players.getArtUrl(root.player)
                visible: !!Players.getArtUrl(root.player)

                layer.enabled: true
                layer.effect: Mask {
                    maskSource: maskWrapper
                }
            }
        }

        Item {
            id: volumeColumn

            visible: !root.isHorizontalVolume
            Layout.fillWidth: true
            Layout.preferredHeight: coverContainer.Layout.preferredHeight
            Layout.leftMargin: Tokens.spacing.medium

            Item {
                id: verticalSlider

                width: 24
                height: parent.height
                anchors.centerIn: parent

                readonly property color fgColour: Colours.palette.m3primary

                readonly property color bgColour: Colours.palette.m3secondaryContainer

                readonly property real pos: Math.max(0, Math.min(1, root.currentVolume))

                readonly property real filledHeight: Math.max(0, (height - handle.implicitHeight - handle.anchors.bottomMargin) * pos)

                StyledRect {
                    id: remaining

                    anchors.top: parent.top
                    anchors.bottom: handle.top
                    anchors.bottomMargin: Tokens.spacing.extraSmall
                    anchors.horizontalCenter: parent.horizontalCenter

                    implicitWidth: parent.width
                    opacity: Math.min(Math.max(0, height), 12) / 12

                    radius: Tokens.rounding.medium
                    bottomLeftRadius: Tokens.rounding.extraSmall / 2
                    bottomRightRadius: Tokens.rounding.extraSmall / 2
                    color: verticalSlider.bgColour
                }

                StyledRect {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 4 * remaining.opacity

                    implicitWidth: 4 * remaining.opacity
                    implicitHeight: 4 * remaining.opacity
                    opacity: remaining.opacity

                    radius: Tokens.rounding.full
                    color: verticalSlider.fgColour
                }

                StyledRect {
                    id: handle

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: filled.top
                    anchors.bottomMargin: Tokens.spacing.extraSmall

                    implicitHeight: 4
                    implicitWidth: {
                        const t = Math.max(0, Math.min(1, (parent.width - 12) / 16));
                        const lerp = (a, b) => a + (b - a) * t;
                        return parent.width * (volumeMouse.pressed ? lerp(3.5, 1.5) : lerp(3, 1.2));
                    }

                    radius: Tokens.rounding.full
                    color: verticalSlider.fgColour

                    Behavior on implicitWidth {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }
                }

                StyledRect {
                    id: filled

                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter

                    implicitWidth: parent.width
                    implicitHeight: verticalSlider.filledHeight

                    radius: Tokens.rounding.medium
                    topLeftRadius: Tokens.rounding.extraSmall / 2
                    topRightRadius: Tokens.rounding.extraSmall / 2
                    color: verticalSlider.fgColour
                }
            }

            MouseArea {
                id: volumeMouse

                anchors.fill: parent
                preventStealing: true

                onPressed: e => {
                    const clickVol = 1.0 - (e.y / height);
                    root.setSpotifyVolume(clickVol);
                }

                onPositionChanged: e => {
                    if (pressed) {
                        const dragVol = 1.0 - (e.y / height);
                        root.setSpotifyVolume(dragVol);
                    }
                }

                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        root.setSpotifyVolume(root.currentVolume + 0.05);
                    else if (event.angleDelta.y < 0)
                        root.setSpotifyVolume(root.currentVolume - 0.05);
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            TextMetrics {
                id: timeMetrics

                text: root.player ? root.lengthStr(Math.max(root.player.position, root.hasUnknownLength ? 0 : root.player.length)).replace(/[1-9]/g, "0") : "00:00"
                font: Tokens.font.label.medium
            }

            StyledText {
                id: positionLabel

                Layout.preferredWidth: timeMetrics.width
                text: root.lengthStr(root.player?.position ?? -1)
                color: Colours.palette.m3onSurfaceVariant
                font: timeMetrics.font
                horizontalAlignment: Text.AlignHCenter
            }

            StyledSlider {
                id: positionSlider

                Layout.fillWidth: true
                value: root.player ? root.player.position / (root.player.length || 1) : 0
                enabled: (root.player?.canSeek ?? false) && !root.hasUnknownLength
                wavy: true
                animateWave: root.player?.isPlaying ?? false
                waveFrequency: 5
                waveDuration: 2000
                interactionOnMove: false
                onInteraction: value => {
                    const p = root.player;
                    if (p?.canSeek && p?.positionSupported)
                        p.position = value * p.length;
                }

                Binding {
                    target: positionLabel
                    property: "text"
                    value: root.lengthStr(positionSlider.pos * (root.player?.length ?? 0))
                    when: positionSlider.dragging
                }
            }

            StyledText {
                Layout.preferredWidth: timeMetrics.width
                text: root.hasUnknownLength ? "--:--" : root.lengthStr(root.player?.length ?? -1)
                color: Colours.palette.m3onSurfaceVariant
                font: timeMetrics.font
                horizontalAlignment: Text.AlignHCenter
            }
        }

        ButtonRow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                type: IconButton.Tonal
                icon: "shuffle"
                isRound: true
                shapeMorph: true
                checked: root.player?.shuffle ?? false
                font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                disabled: !root.player?.shuffleSupported
                onClicked: if (root.player)
                    root.player.shuffle = !root.player.shuffle
                implicitWidth: Math.round(implicitHeight * 0.9)
            }

            IconButton {
                id: previousBtn

                type: IconButton.Tonal
                icon: "skip_previous"
                isRound: true
                shapeMorph: true
                font: Tokens.font.icon.large
                disabled: !root.player?.canGoPrevious
                onClicked: root.player?.previous()
            }

            IconButton {
                id: playPauseBtn

                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                isRound: true
                shapeMorph: true
                fillWidth: true
                checked: root.player?.isPlaying ?? false
                font: Tokens.font.icon.large
                disabled: !root.player?.canTogglePlaying
                onClicked: root.player?.togglePlaying()
            }

            IconButton {
                id: nextBtn

                type: IconButton.Tonal
                icon: "skip_next"
                isRound: true
                shapeMorph: true
                font: Tokens.font.icon.large
                disabled: !root.player?.canGoNext
                onClicked: root.player?.next()
            }

            IconButton {
                type: IconButton.Tonal
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                isRound: true
                shapeMorph: true
                checked: root.player?.loopState === MprisLoopState.Track || root.player?.loopState === MprisLoopState.Playlist
                font: Tokens.font.icon.builders.medium.weight(Font.Medium).build()
                disabled: !root.player?.loopSupported
                onClicked: {
                    if (!root.player)
                        return;
                    const state = root.player.loopState;
                    if (state === MprisLoopState.None)
                        root.player.loopState = MprisLoopState.Track;
                    else if (state === MprisLoopState.Track)
                        root.player.loopState = MprisLoopState.Playlist;
                    else
                        root.player.loopState = MprisLoopState.None;
                }
                implicitWidth: Math.round(implicitHeight * 0.9)
            }
        }

        CustomMouseArea {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            visible: root.isHorizontalVolume
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    root.setSpotifyVolume(root.currentVolume + 0.05);
                else if (event.angleDelta.y < 0)
                    root.setSpotifyVolume(root.currentVolume - 0.05);
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: root.currentVolume
                onInteraction: v => root.setSpotifyVolume(v)
            }
        }
    }
}
