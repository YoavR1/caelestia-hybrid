pragma Singleton

import ".."
import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.services
import qs.utils
import qs.modules.nexus

Searcher {
    id: root

    function transformSearch(search: string): string {
        return search.slice(GlobalConfig.launcher.actionPrefix.length);
    }

    // An action that autocompletes into a gated feature is not offered when it is off.
    // Keeps the launcher's list honest; AppList refuses the prefix as well.
    function featureEnabled(action: var): bool {
        const command = action.command ?? [];
        if (command.length < 2 || command[0] !== "autocomplete")
            return true;

        const features = GlobalConfig.hybrid.features;
        switch (command[1]) {
        case "emoji":
            return features.emojiPicker;
        case "clipboard":
            return features.clipboard;
        case "windows":
            return features.windowSwitcher;
        case "keybinds":
            return features.keybindViewer;
        case "wallpaper":
            return true;
        default:
            return true;
        }
    }

    list: variants.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.actions

    Variants {
        id: variants

        model: GlobalConfig.launcher.actions.filter(a => (a.enabled ?? true) && (GlobalConfig.launcher.enableDangerousActions || !(a.dangerous ?? false)) && root.featureEnabled(a))

        Action {}
    }

    component Action: QtObject {
        required property var modelData
        readonly property string name: modelData.name ?? qsTr("Unnamed")
        readonly property string desc: modelData.description ?? qsTr("No description")
        readonly property string icon: modelData.icon ?? "help_outline"
        readonly property list<string> command: modelData.command ?? []
        readonly property bool enabled: modelData.enabled ?? true
        readonly property bool dangerous: modelData.dangerous ?? false

        function onClicked(list: AppList): void {
            if (command.length === 0)
                return;

            if (command[0] === "autocomplete" && command.length > 1) {
                list.search.text = `${GlobalConfig.launcher.actionPrefix}${command[1]} `;
            } else if (command[0] === "setMode" && command.length > 1) {
                list.screenState.launcher = false;
                Colours.setMode(command[1]);
            } else if (command[0] === "nexus") {
                // Nexus lives in this same instance, so open it here. Going out through
                // `caelestia shell nexus open` sends the call to `qs -c caelestia`, which is
                // the shell installed at /etc/xdg/quickshell/caelestia -- not the one the
                // launcher is running in. See T53.
                list.screenState.launcher = false;
                WindowFactory.create();
            } else {
                list.screenState.launcher = false;
                if (!SessionManager.exec(command))
                    Quickshell.execDetached(command);
            }
        }
    }
}
