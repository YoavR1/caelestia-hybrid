pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Column {
    id: root

    required property ScreenState screenState

    padding: Tokens.padding.large
    rightPadding: CUtils.clamp(padding - Config.border.thickness, 0, padding)
    spacing: Tokens.spacing.large

    Repeater {
        id: topButtonsRepeater

        model: Config.session.buttons.slice(0, Math.min(2, Config.session.buttons.length))

        SessionButton {
            id: topBtn

            required property var modelData
            required property int index

            icon: modelData.icon
            command: modelData.command

            Component.onCompleted: {
                if (index === 0)
                    topBtn.forceActiveFocus();
            }

            Connections {
                function onLauncherChanged(): void {
                    if (index === 0 && !root.screenState.launcher)
                        topBtn.forceActiveFocus();
                }

                target: root.screenState
            }

            KeyNavigation.up: index > 0 ? topButtonsRepeater.itemAt(index - 1) : null
            KeyNavigation.down: index < topButtonsRepeater.count - 1
                ? topButtonsRepeater.itemAt(index + 1)
                : (bottomButtonsRepeater.count > 0 ? bottomButtonsRepeater.itemAt(0) : null)
        }
    }

    AnimatedImage {
        width: Tokens.sizes.session.button
        height: Tokens.sizes.session.button
        sourceSize.width: width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1)

        playing: visible
        asynchronous: true
        speed: Config.general.sessionGifSpeed
        source: Paths.absolutePath(Config.paths.sessionGif)
        fillMode: AnimatedImage.PreserveAspectFit
        visible: Config.paths.sessionGif !== ""
    }

    Repeater {
        id: bottomButtonsRepeater

        model: Config.session.buttons.length > 2 ? Config.session.buttons.slice(2) : []

        SessionButton {
            required property var modelData
            required property int index

            icon: modelData.icon
            command: modelData.command

            KeyNavigation.up: index === 0
                ? (topButtonsRepeater.count > 0 ? topButtonsRepeater.itemAt(topButtonsRepeater.count - 1) : null)
                : bottomButtonsRepeater.itemAt(index - 1)
            KeyNavigation.down: index < bottomButtonsRepeater.count - 1
                ? bottomButtonsRepeater.itemAt(index + 1)
                : null
        }
    }

    component SessionButton: IconButton {
        id: button

        required property list<string> command

        function exec(): void {
            if (!SessionManager.exec(command)) {
                if (command.length > 0) {
                    let hasShellOp = command.some(arg => arg.includes(" ") || arg === "&&" || arg === "||" || arg === ";" || arg === "|" || arg === ">" || arg === "<");
                    if (hasShellOp || command.length === 1) {
                        Quickshell.execDetached(["sh", "-c", command.join(" ")]);
                    } else {
                        Quickshell.execDetached(command);
                    }
                }
            }
        }

        implicitWidth: Tokens.sizes.session.button
        implicitHeight: Tokens.sizes.session.button

        inactiveColour: activeFocus ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer
        inactiveOnColour: activeFocus ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        radius: pressed ? Tokens.rounding.medium : activeFocus ? Tokens.rounding.extraLarge : Tokens.rounding.largeIncreased
        font: Tokens.font.icon.builders.large.scale(1.3).build()
        onClicked: exec()

        Keys.onEnterPressed: exec()
        Keys.onReturnPressed: exec()
        Keys.onEscapePressed: root.screenState.session = false
        Keys.onPressed: event => {
            if (!Config.session.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if ((event.key === Qt.Key_J || event.key === Qt.Key_N) && KeyNavigation.down) {
                    KeyNavigation.down.focus = true;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_K || event.key === Qt.Key_P) && KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab && KeyNavigation.down) {
                KeyNavigation.down.focus = true;
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (KeyNavigation.up) {
                    KeyNavigation.up.focus = true;
                    event.accepted = true;
                }
            }
        }
    }
}
