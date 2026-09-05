import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config // qmllint disable unused-imports
import qs.components.misc
import qs.services
import qs.modules.nexus

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "nexus"
        description: "Open nexus"
        onPressed: WindowFactory.create()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = ShellState.forActive();
            if (!v)
                return;
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (!screenState)
                return;
            screenState.dashboard = !screenState.dashboard;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (!screenState)
                return;
            screenState.session = !screenState.session;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const screenState = ShellState.forActive();
                if (!screenState)
                    return;
                screenState.launcher = !screenState.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (!screenState)
                return;
            Visibilities.initialSidebarTab = "notifications";
            screenState.sidebar = !screenState.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "aiAssistant"
        description: "Toggle AI Assistant"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            Visibilities.initialSidebarTab = "ai";
            visibilities.sidebar = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const screenState = ShellState.forActive();
            if (!screenState)
                return;
            screenState.utilities = !screenState.utilities;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "emoji"
        description: "Open emoji picker"
        onPressed: {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}emoji `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "clipboard"
        description: "Open clipboard history"
        onPressed: {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}clipboard `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "windowSwitcher"
        description: "Open window switcher"
        onPressed: {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}windows `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "wallpaper"
        description: "Open wallpaper picker"
        onPressed: {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}wallpaper `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "keybinds"
        description: "Open keybinds list"
        onPressed: {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}keybinds `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "workspaceOverview"
        description: "Toggle workspace overview"
        onPressed: {
            if (root.hasFullscreen || !GlobalConfig.hybrid.features.overview)
                return;
            const screenState = ShellState.forActive();
            if (!screenState)
                return;
            // The two implementations of hybrid.variants.overview keep their own visibility:
            // MiDnight's is a panel in modules/drawers driven by workspaceDrawer, OP's is a
            // separate Scope with its own per-screen flag. One shortcut, whichever is selected.
            if (GlobalConfig.hybrid.variants.overview === HybridVariant.Op)
                screenState.overview = !screenState.overview;
            else
                screenState.workspaceDrawer = !screenState.workspaceDrawer;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            // Checked in this order so the warning is about the drawer name. Going through
            // list() first conflated "no active screen" with "no such drawer", and reported
            // the latter for the former.
            const screenState = ShellState.forActive();
            if (!screenState)
                return;
            if (typeof screenState[drawer] !== "boolean") {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
                return;
            }
            if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                return;
            if (drawer === "workspaceDrawer" && !GlobalConfig.hybrid.features.overview)
                return;
            screenState[drawer] = !screenState[drawer];
        }

        function toggleTab(drawer: string, tab: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                if (drawer === "sidebar" && tab !== "") {
                    Visibilities.initialSidebarTab = tab;
                    const visibilities = Visibilities.getForActive();
                    if (!visibilities)
                        return;
                    visibilities.sidebar = true;
                    return;
                }
                const visibilities = Visibilities.getForActive();
                if (!visibilities)
                    return;
                visibilities[drawer] = !visibilities[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const screenState = ShellState.forActive();
            if (!screenState)
                return "";
            return Object.keys(screenState).filter(k => typeof screenState[k] === "boolean").join("\n");
        }

        function isOpen(drawer: string): string {
            const screenState = ShellState.forActive();
            if (!screenState)
                return "unknown";
            if (typeof screenState[drawer] !== "boolean")
                return "unknown";
            return screenState[drawer] ? "1" : "0";
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.create();
        }

        function openPage(page: int): void {
            WindowFactory.openPage(page);
        }

        target: "nexus"
    }

    IpcHandler {
        function openEmoji(): void {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}emoji `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }

        function openClipboard(): void {
            if (root.hasFullscreen)
                return;
            Visibilities.launcherInitialSearch = `${GlobalConfig.launcher.actionPrefix}clipboard `;
            const visibilities = Visibilities.getForActive();
            if (!visibilities)
                return;
            visibilities.launcher = true;
        }

        target: "launcher"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
