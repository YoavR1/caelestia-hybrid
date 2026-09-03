pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandIcon: expandIcon

    readonly property int padding: Config.bar.tray.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property int spacing: Config.bar.tray.background ? Tokens.spacing.medium : Tokens.spacing.extraSmall

    property bool expanded

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    readonly property real nonAnimHeight: {
        if (isHorizontal)
            return Tokens.sizes.bar.innerWidth;
        if (!Config.bar.tray.compact)
            return layout.implicitHeight + padding * 2;
        const pad = (Config.bar.tray.background ? Tokens.padding.extraSmall : 0) + padding;
        if (expanded)
            return expandIcon.implicitHeight + layout.implicitHeight + spacing + pad;
        return Math.max(Config.bar.tray.background ? width : 0, expandIcon.implicitHeight + pad);
    }

    readonly property real nonAnimWidth: {
        if (!isHorizontal)
            return Tokens.sizes.bar.innerWidth;
        if (!Config.bar.tray.compact)
            return layout.implicitWidth + padding * 2;
        return (expanded ? expandIcon.implicitWidth + layout.implicitWidth + spacing : expandIcon.implicitWidth) + padding * 2;
    }

    clip: true
    visible: height > 0

    implicitWidth: isHorizontal ? nonAnimWidth : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : nonAnimHeight

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Grid {
        id: layout

        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
        anchors.top: root.isHorizontal ? undefined : parent.top
        anchors.topMargin: root.isHorizontal ? 0 : root.padding
        anchors.left: root.isHorizontal ? parent.left : undefined
        anchors.leftMargin: root.isHorizontal ? root.padding : 0

        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        flow: root.isHorizontal ? Grid.LeftToRight : Grid.TopToBottom

        spacing: Tokens.spacing.small

        opacity: root.expanded || !Config.bar.tray.compact ? 1 : 0

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
            }

            TrayItem {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: expandIcon

        asynchronous: true

        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
        anchors.bottom: root.isHorizontal ? undefined : parent.bottom
        anchors.right: root.isHorizontal ? parent.right : undefined

        active: Config.bar.tray.compact && items.count > 0

        sourceComponent: Item {
            implicitWidth: root.isHorizontal ? (expandIconInner.implicitWidth - Tokens.padding.small * 2) : expandIconInner.implicitWidth
            implicitHeight: root.isHorizontal ? expandIconInner.implicitHeight : (expandIconInner.implicitHeight - Tokens.padding.small * 2)

            MaterialIcon {
                id: expandIconInner

                anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
                anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
                anchors.bottom: root.isHorizontal ? undefined : parent.bottom
                anchors.right: root.isHorizontal ? parent.right : undefined
                anchors.bottomMargin: root.isHorizontal ? 0 : (Config.bar.tray.background ? Tokens.padding.extraSmall : -Tokens.padding.small)
                anchors.rightMargin: root.isHorizontal ? (Config.bar.tray.background ? Tokens.padding.extraSmall : -Tokens.padding.small) : 0
                text: "expand_less"
                color: Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.medium
                rotation: root.isHorizontal ? (root.expanded ? 270 : 90) : (root.expanded ? 180 : 0)

                Behavior on rotation {
                    Anim {}
                }

                Behavior on anchors.bottomMargin {
                    enabled: !root.isHorizontal

                    Anim {}
                }

                Behavior on anchors.rightMargin {
                    enabled: root.isHorizontal

                    Anim {}
                }
            }
        }
    }

    Behavior on implicitHeight {
        enabled: !root.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        enabled: root.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }
}
