pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return qsTr("Desktop");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property int maxSize: {
        const start = bar.sections[0];
        const end = bar.sections[2];
        if (bar.isHorizontal) {
            const availLeft = bar.width / 2 - (start.x + start.width);
            const availRight = end.x - bar.width / 2;
            const availCenter = 2 * Math.min(availLeft, availRight);
            return Math.max(0, availCenter - bar.spacing * 2);
        } else {
            const availTop = bar.height / 2 - (start.y + start.height);
            const availBottom = end.y - bar.height / 2;
            const availCenter = 2 * Math.min(availTop, availBottom);
            return Math.max(0, availCenter - bar.spacing * 2);
        }
    }
    property Title current: text1

    clip: true
    implicitWidth: bar.isHorizontal ? (icon.implicitWidth + current.width + current.anchors.leftMargin) : Math.max(icon.implicitWidth, current.width)
    implicitHeight: bar.isHorizontal ? Math.max(icon.implicitHeight, current.height) : (icon.implicitHeight + current.height + current.anchors.topMargin)

    Loader {
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else if (Hypr.activeToplevel) {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.bar.isHorizontal ? root.mapToItem(null, root.implicitWidth / 2, 0).x : root.mapToItem(null, 0, root.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.horizontalCenter: root.bar.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.bar.isHorizontal ? parent.verticalCenter : undefined

        animate: true
        text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: root.colour
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font: root.Tokens.font.body.builders.small.letterSpacing(1.4).build()
        elide: Qt.ElideRight
        elideWidth: root.maxSize - icon.width

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitHeight {
        enabled: !root.bar.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        enabled: root.bar.isHorizontal

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    component Title: Item {
        id: textContainer

        property alias text: styledText.text

        width: root.bar.isHorizontal ? styledText.implicitWidth : styledText.implicitHeight
        height: root.bar.isHorizontal ? styledText.implicitHeight : styledText.implicitWidth

        anchors.horizontalCenter: root.bar.isHorizontal ? undefined : icon.horizontalCenter
        anchors.verticalCenter: root.bar.isHorizontal ? icon.verticalCenter : undefined
        anchors.top: root.bar.isHorizontal ? undefined : icon.bottom
        anchors.topMargin: root.bar.isHorizontal ? 0 : Tokens.spacing.small
        anchors.left: root.bar.isHorizontal ? icon.right : undefined
        anchors.leftMargin: root.bar.isHorizontal ? Tokens.spacing.small : 0

        // Custom Title component does not have font/color directly, StyledText child does
        opacity: root.current === this ? 1 : 0

        StyledText {
            id: styledText

            anchors.centerIn: parent

            font.pointSize: metrics.font.pointSize
            font.family: metrics.font.family
            color: root.colour

            rotation: root.bar.isHorizontal ? 0 : (root.Config.bar.activeWindow.inverted ? 270 : 90)
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
