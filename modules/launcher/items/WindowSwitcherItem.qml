import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.images
import qs.services

Item {
    id: root

    required property var modelData
    required property var list

    function clicked(): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:0x${root.modelData.address}" })` : `focuswindow address:0x${root.modelData.address}`);
        root.list.screenState.launcher = false;
    }

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0

    implicitWidth: previewBox.width + Tokens.padding.largeIncreased * 2
    implicitHeight: previewBox.height + label.height + Tokens.spacing.small / 2 + Tokens.padding.large + Tokens.padding.medium

    StateLayer {
        radius: Tokens.rounding.medium
        onClicked: root.clicked()
    }

    StyledRect {
        id: shadowRect

        anchors.fill: previewBox
        radius: previewBox.radius
        color: Colours.layer(Colours.palette.m3surfaceContainerHighest, root.PathView.isCurrentItem ? 1 : 0)
        opacity: root.PathView.isCurrentItem ? 1 : 0

        Behavior on opacity {
            Anim {}
        }
    }

    StyledClippingRect {
        id: previewBox

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.medium

        implicitWidth: Tokens.sizes.launcher.windowSwitcherWidth
        implicitHeight: implicitWidth / 16 * 9

        SafeScreencopy {
            anchors.fill: parent
            captureSource: {
                const win = root.modelData;
                if (!win || !win.wayland) return null;
                const ipc = win.lastIpcObject;
                if (ipc) {
                    if (ipc.mapped === false || ipc.hidden) return null;
                    if (ipc.size && (ipc.size[0] <= 0 || ipc.size[1] <= 0)) return null;
                } else {
                    if (win.mapped === false || win.hidden) return null;
                    if (win.size && (win.size[0] <= 0 || win.size[1] <= 0)) return null;
                }
                return win.wayland;
            }
            live: root.list.screenState.launcher && root.opacity > 0
            smooth: !(root.PathView.view?.moving ?? false)
        }
    }

    StyledText {
        id: label

        anchors.top: previewBox.bottom
        anchors.topMargin: Tokens.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter

        width: previewBox.width - Tokens.padding.medium * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.modelData?.title ?? ""
        font: Tokens.font.body.medium
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }
}
