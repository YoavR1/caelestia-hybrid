pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property var bar
    required property real borderThickness
    required property ScreenState screenState

    readonly property alias content: content
    readonly property bool isHorizontal: bar.isHorizontal
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    Config.screen: screen.name

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: isHorizontal ? content.implicitWidth : content.implicitWidth * (1 - offsetScale)
    implicitHeight: isHorizontal ? content.implicitHeight * (1 - offsetScale) : content.implicitHeight

    x: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        if (isHorizontal) {
            if (content.sidebarOpen && !content.isDockPopout && content.currentSection === "end")
                return parent.width - content.nonAnimWidth;

            const off = content.currentCenter - parent.leftMargin - content.nonAnimWidth / 2; // qmllint disable missing-property
            const diff = parent.width - Math.floor(off + content.nonAnimWidth);
            if (diff < 0)
                return off + diff;
            return Math.max(off, 0);
        }
        if (bar.position === "right")
            return parent.width - implicitWidth;
        return 0;
    }

    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;
        if (isHorizontal) {
            if (bar.position === "bottom")
                return parent.height - implicitHeight;
            return 0;
        }

        const off = content.currentCenter - parent.topMargin - content.nonAnimHeight / 2; // qmllint disable missing-property
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: content.isDetached || root.isHorizontal

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: content.isDetached || (!root.isHorizontal && root.offsetScale < 1)

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale
        screenState: root.screenState

        // Apply slide animation margins based on edge
        anchors.leftMargin: root.bar.position === "left" ? (-implicitWidth - 5) * root.offsetScale : 0
        anchors.rightMargin: root.bar.position === "right" ? (-implicitWidth - 5) * root.offsetScale : 0
        anchors.topMargin: root.bar.position === "top" ? (-implicitHeight - 5) * root.offsetScale : 0
        anchors.bottomMargin: root.bar.position === "bottom" ? (-implicitHeight - 5) * root.offsetScale : 0

        states: [
            State {
                name: "left"
                when: root.bar.position === "left"

                AnchorChanges {
                    target: content
                    anchors.left: parent.left
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: undefined
                }
            },
            State {
                name: "right"
                when: root.bar.position === "right"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.top: undefined
                    anchors.bottom: undefined
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: undefined
                }
            },
            State {
                name: "top"
                when: root.bar.position === "top"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: undefined
                    anchors.top: parent.top
                    anchors.bottom: undefined
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            },
            State {
                name: "bottom"
                when: root.bar.position === "bottom"

                AnchorChanges {
                    target: content
                    anchors.left: undefined
                    anchors.right: undefined
                    anchors.top: undefined
                    anchors.bottom: parent.bottom
                    anchors.verticalCenter: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        ]
    }
}
