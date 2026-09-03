pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services

// The little "reset this option" button that appears once a setting has been changed.
IconButton {
    id: root

    property var configNode
    property string propertyName: ""

    // Not a binding: isOverride() is a plain call, so nothing would re-evaluate it. The
    // node tells us when a key changes instead.
    property bool isOverridden: false

    function refresh(): void {
        root.isOverridden = !!root.configNode && root.propertyName !== "" && root.configNode.isOverride(root.propertyName);
    }

    visible: root.isOverridden
    icon: "restart_alt"
    type: IconButton.Text
    font: Tokens.font.icon.small
    inactiveOnColour: Colours.palette.m3tertiary

    Layout.alignment: Qt.AlignVCenter

    onConfigNodeChanged: root.refresh()
    onPropertyNameChanged: root.refresh()
    Component.onCompleted: root.refresh()

    onClicked: {
        if (root.configNode && root.propertyName !== "") {
            root.configNode.resetOption(root.propertyName);
            root.refresh();
        }
    }

    Connections {
        function onOptionChanged(key: string): void {
            if (key === root.propertyName)
                root.refresh();
        }

        target: root.configNode ?? null
    }
}
