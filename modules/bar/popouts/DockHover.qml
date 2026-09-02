pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

RowLayout {
    id: root

    required property PopoutState popouts
    property var model: popouts.dockModel

    property MprisPlayer player: {
        if (!model)
            return null;
        return Players.list.find(p => p.identity.toLowerCase().includes(model.appClass.toLowerCase()) || (model.id && p.identity.toLowerCase().includes(model.id.toLowerCase().replace(".desktop", "")))) || null;
    }

    spacing: Tokens.spacing.medium

    // Fallback for pinned apps with no active windows
    StyledRect {
        visible: !root.model || !root.model.toplevels || root.model.toplevels.length === 0
        Layout.alignment: Qt.AlignTop
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainer
        clip: true
        implicitWidth: fallbackLayout.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: fallbackLayout.implicitHeight + Tokens.padding.medium * 2

        ColumnLayout {
            id: fallbackLayout

            anchors.centerIn: parent
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.medium

                IconImage {
                    id: fallbackIcon

                    asynchronous: true
                    Layout.alignment: Qt.AlignVCenter
                    implicitSize: fallbackDetails.implicitHeight
                    source: root.model ? Icons.getAppIcon(root.model.iconName, "image-missing") : ""
                }

                ColumnLayout {
                    id: fallbackDetails

                    spacing: 0
                    Layout.fillWidth: true

                    StyledText {
                        Layout.fillWidth: true
                        text: root.model ? (root.model.entry ? root.model.entry.name : root.model.appClass) : ""
                        font.pointSize: Tokens.font.body.medium.pointSize
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Repeater {
        model: root.model ? root.model.toplevels : []

        delegate: StyledRect {
            required property var modelData

            readonly property real windowRatio: (modelData.lastIpcObject && modelData.lastIpcObject.size[0] > 0) ? (modelData.lastIpcObject.size[1] / modelData.lastIpcObject.size[0]) : 0.75
            readonly property real targetWidth: Tokens.sizes.bar.windowPreviewSize
            readonly property real targetHeight: Math.max(50, Math.min(targetWidth * windowRatio, Tokens.sizes.bar.windowPreviewSize * 1.5))

            Layout.alignment: Qt.AlignTop
            radius: Tokens.rounding.medium
            color: Colours.tPalette.m3surfaceContainer
            clip: true
            implicitWidth: cardLayout.implicitWidth + Tokens.padding.medium * 2
            implicitHeight: cardLayout.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: cardLayout

                anchors.centerIn: parent
                spacing: Tokens.spacing.medium

                // Title row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: targetWidth

                    IconImage {
                        asynchronous: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitSize: titleText.implicitHeight
                        source: root.model ? Icons.getAppIcon(root.model.iconName, "image-missing") : ""
                    }

                    StyledText {
                        id: titleText

                        Layout.fillWidth: true
                        text: modelData.title || ""
                        font.pointSize: Tokens.font.body.small.pointSize
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledRect {
                        implicitWidth: winfoIcon.implicitHeight + Tokens.padding.small * 2
                        implicitHeight: winfoIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: Colours.tPalette.m3surfaceVariant

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            // Set the specific client to be used by the window info popout
                            onClicked: {
                                root.popouts.selectedClientAddress = modelData.address;
                                root.popouts.detachRequested("winfo");
                            }
                        }

                        MaterialIcon {
                            id: winfoIcon

                            anchors.centerIn: parent
                            text: "chevron_right"
                            fontStyle.pointSize: Tokens.font.body.medium.pointSize
                        }
                    }

                    StyledRect {
                        implicitWidth: closeIcon.implicitHeight + Tokens.padding.small * 2
                        implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.small
                        color: Colours.tPalette.m3surfaceVariant

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            onClicked: {
                                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "address:0x${modelData.address}" })` : `closewindow address:0x${modelData.address}`);
                                root.popouts.hasCurrent = false;
                            }
                        }

                        MaterialIcon {
                            id: closeIcon

                            anchors.centerIn: parent
                            text: "close"
                            fontStyle.pointSize: Tokens.font.body.medium.pointSize
                        }
                    }
                }

                // Preview
                Item {
                    Layout.preferredWidth: targetWidth
                    Layout.preferredHeight: targetHeight

                    StateLayer {
                        radius: Tokens.rounding.small
                        color: "transparent"

                        onClicked: {
                            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "address:0x${modelData.address}" })` : `focuswindow address:0x${modelData.address}`);
                            root.popouts.hasCurrent = false;
                        }

                        ClippingWrapperRectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: Tokens.rounding.small

                            SafeScreencopy {
                                captureSource: {
                                    if (!modelData || !modelData.wayland) return null; // qmllint disable unresolved-type
                                    const ipc = modelData.lastIpcObject;
                                    if (ipc) {
                                        if (ipc.mapped === false || ipc.hidden) return null;
                                        if (ipc.size && (ipc.size[0] <= 0 || ipc.size[1] <= 0)) return null;
                                    }
                                    return modelData.wayland;
                                }
                                live: visible
                                constraintSize.width: targetWidth
                                constraintSize.height: targetHeight
                            }
                        }
                    }
                }

                // Media controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.medium
                    visible: !!root.player

                    Item {
                        implicitWidth: prevIcon.implicitHeight + Tokens.padding.small * 2
                        implicitHeight: prevIcon.implicitHeight + Tokens.padding.small * 2
                        visible: root.player ? root.player.canGoPrevious : false

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            onClicked: root.player.previous()
                        }

                        MaterialIcon {
                            id: prevIcon

                            anchors.centerIn: parent
                            text: "skip_previous"
                            fontStyle.pointSize: Tokens.font.body.large.pointSize
                        }
                    }

                    Item {
                        implicitWidth: playIcon.implicitHeight + Tokens.padding.small * 2
                        implicitHeight: playIcon.implicitHeight + Tokens.padding.small * 2
                        visible: root.player ? root.player.canTogglePlaying : false

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            onClicked: root.player.togglePlaying()
                        }

                        MaterialIcon {
                            id: playIcon

                            anchors.centerIn: parent
                            text: (root.player && root.player.isPlaying) ? "pause" : "play_arrow"
                            fontStyle.pointSize: Tokens.font.body.large.pointSize
                        }
                    }

                    Item {
                        implicitWidth: nextIcon.implicitHeight + Tokens.padding.small * 2
                        implicitHeight: nextIcon.implicitHeight + Tokens.padding.small * 2
                        visible: root.player ? root.player.canGoNext : false

                        StateLayer {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            onClicked: root.player.next()
                        }

                        MaterialIcon {
                            id: nextIcon

                            anchors.centerIn: parent
                            text: "skip_next"
                            fontStyle.pointSize: Tokens.font.body.large.pointSize
                        }
                    }
                }
            }
        }
    }
}
