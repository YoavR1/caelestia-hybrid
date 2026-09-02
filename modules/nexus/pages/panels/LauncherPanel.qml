pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Launcher")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // General
        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            text: qsTr("Enabled")
            configNode: root.targetConfig.launcher
            propertyName: "enabled"
            checked: root.targetConfig.launcher.enabled
            onToggled: {
                root.targetConfig.launcher.enabled = checked;
            }
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal when the cursor reaches the screen edge")
            configNode: root.targetConfig.launcher
            propertyName: "showOnHover"
            checked: root.targetConfig.launcher.showOnHover
            onToggled: {
                root.targetConfig.launcher.showOnHover = checked;
            }
        }

        TextFieldRow {
            id: prefixRow

            last: true
            label: qsTr("Action prefix")
            subtext: qsTr("Prefix used to run actions in the launcher")
            configNode: root.targetConfig.launcher
            propertyName: "actionPrefix"
            errorText: qsTr("Prefix must not be alphanumeric")
            value: root.targetConfig.launcher.actionPrefix === ">" ? "" : root.targetConfig.launcher.actionPrefix
            placeholderText: ">"
            maximumLength: 1
            smallField: true
            validate: /^[^a-zA-Z0-9\s]$/
            onEditingFinished: value => {
                if (!field.valid)
                    return;
                root.targetConfig.launcher.actionPrefix = value || ">";
                if (root.targetConfig.launcher.actionPrefix === ">")
                    clear();
            }
        }

        // Display
        SectionHeader {
            text: qsTr("Display")
        }

        StepperRow {
            first: true
            label: qsTr("Max items shown")
            configNode: root.targetConfig.launcher
            propertyName: "maxShown"
            value: root.targetConfig.launcher.maxShown
            from: 1
            to: 20
            stepSize: 1
            onMoved: v => {
                root.targetConfig.launcher.maxShown = v;
            }
        }

        StepperRow {
            label: qsTr("Max wallpapers")
            configNode: root.targetConfig.launcher
            propertyName: "maxWallpapers"
            value: root.targetConfig.launcher.maxWallpapers
            from: 1
            to: 30
            stepSize: 1
            onMoved: v => {
                root.targetConfig.launcher.maxWallpapers = v;
            }
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the launcher opens")
            configNode: root.targetConfig.launcher
            propertyName: "dragThreshold"
            value: root.targetConfig.launcher.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => {
                root.targetConfig.launcher.dragThreshold = v;
            }
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Vim keybinds")
            subtext: qsTr("Navigate results with Ctrl+hjkl")
            configNode: root.targetConfig.launcher
            propertyName: "vimKeybinds"
            checked: root.targetConfig.launcher.vimKeybinds
            onToggled: {
                root.targetConfig.launcher.vimKeybinds = checked;
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Enable dangerous actions")
            subtext: qsTr("Allow actions that shut down or log out")
            configNode: root.targetConfig.launcher
            propertyName: "enableDangerousActions"
            checked: root.targetConfig.launcher.enableDangerousActions
            onToggled: {
                root.targetConfig.launcher.enableDangerousActions = checked;
            }
        }

        // Fuzzy search
        SectionHeader {
            text: qsTr("Fuzzy search")
        }

        ToggleRow {
            first: true
            text: qsTr("Apps")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "apps"
            checked: root.targetConfig.launcher.useFuzzy.apps
            onToggled: {
                root.targetConfig.launcher.useFuzzy.apps = checked;
            }
        }

        ToggleRow {
            text: qsTr("Actions")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "actions"
            checked: root.targetConfig.launcher.useFuzzy.actions
            onToggled: {
                root.targetConfig.launcher.useFuzzy.actions = checked;
            }
        }

        ToggleRow {
            text: qsTr("Schemes")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "schemes"
            checked: root.targetConfig.launcher.useFuzzy.schemes
            onToggled: {
                root.targetConfig.launcher.useFuzzy.schemes = checked;
            }
        }

        ToggleRow {
            text: qsTr("Variants")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "variants"
            checked: root.targetConfig.launcher.useFuzzy.variants
            onToggled: {
                root.targetConfig.launcher.useFuzzy.variants = checked;
            }
        }

        ToggleRow {
            last: true
            text: qsTr("Wallpapers")
            configNode: root.targetConfig.launcher.useFuzzy
            propertyName: "wallpapers"
            checked: root.targetConfig.launcher.useFuzzy.wallpapers
            onToggled: {
                root.targetConfig.launcher.useFuzzy.wallpapers = checked;
            }
        }
    }
}
