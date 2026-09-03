import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property FileSystemEntry modelData
    required property ScreenState screenState

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0 // qmllint disable missing-property

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    implicitWidth: image.width + Tokens.padding.medium * 2
    implicitHeight: image.height + label.height + Tokens.spacing.extraSmall + Tokens.padding.large + Tokens.padding.medium

    Process {
        id: thumbGenerator

        // $1 is the thumbnail, $2 the source video. Wallpaper filenames are the user's and
        // routinely contain quotes, spaces and $; none of that reaches the shell as syntax.
        command: ["sh", "-c", 'mkdir -p "$(dirname "$1")" && ffmpeg -i "$2" -vframes 1 -q:v 2 "$1" -y', "sh", thumbImg.path.toString().replace("file://", ""), root.modelData.path]
        onExited: { // qmllint disable signal-handler-parameters
            let oldSource = thumbImg.path;
            thumbImg.path = "";
            thumbImg.path = oldSource;
        }
    }

    StateLayer {
        radius: Tokens.rounding.large
        onClicked: {
            Wallpapers.setWallpaper(root.modelData.path);
            root.screenState.launcher = false;
        }
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 4

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    StyledClippingRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        implicitWidth: Tokens.sizes.launcher.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        MaterialIcon {
            anchors.centerIn: parent
            text: "image"
            color: Colours.tPalette.m3outline
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(2).weight(Font.DemiBold).build()
            visible: thumbImg.status !== Image.Ready
        }

        CachingImage {
            id: thumbImg

            anchors.fill: parent
            path: Wallpapers.getThumbnailPath(root.modelData.path)
            smooth: !root.PathView.view.moving
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(image.implicitWidth * dpr, image.implicitHeight * dpr);
            }
            onStatusChanged: {
                if (status === Image.Error && Images.isVideo(root.modelData.name)) {
                    if (!thumbGenerator.running) {
                        thumbGenerator.running = true;
                    }
                }
            }
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Tokens.spacing.extraSmall
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Tokens.padding.medium * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: {
            if (root.modelData.name === "project.json") {
                let content = CUtils.readFile(root.modelData.path);
                try {
                    let json = JSON.parse(content);
                    if (json.title)
                        return json.title;
                } catch (e) {}
                return root.modelData.path.split('/').slice(-2, -1)[0];
            }
            return root.modelData.name;
        }
        font: Tokens.font.label.medium
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }
}
