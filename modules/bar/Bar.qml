pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.components

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int vPadding: Tokens.padding.large

    readonly property bool isHorizontal: Config.bar.position === "top" || Config.bar.position === "bottom"

    readonly property real spacing: Tokens.spacing.medium

    readonly property list<EntrySection> sections: [startSection, centerSection, endSection]

    function entryAt(pos: real): EntryWrapper {
        const x = isHorizontal ? pos : width / 2;
        const y = isHorizontal ? height / 2 : pos;

        for (const section of root.sections) {
            const local = section.mapFromItem(root, x, y);
            const wrapper = section.childAt(local.x, local.y) as EntryWrapper;
            if (wrapper?.visible)
                return wrapper;
        }
        return null;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (const section of root.sections) {
            for (let i = 0; i < section.count; i++) {
                const wrapper = section.itemAt(i) as EntryWrapper;
                if (!wrapper)
                    continue;
                const tray = wrapper.item as Tray;
                if (tray)
                    tray.expanded = false;
            }
        }
    }

    function sectionIdFor(wrapper: EntryWrapper): string {
        if (wrapper.parent === startSection)
            return "start";
        if (wrapper.parent === centerSection)
            return "center";
        if (wrapper.parent === endSection)
            return "end";
        return "";
    }

    function checkPopout(pos: real): void {
        const ch = root.entryAt(pos);

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            if (popouts.hasCurrent && (popouts.currentName === "dockcontext" || popouts.currentName === "dockhover" || popouts.currentName === "activewindow"))
                return;
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const top = isHorizontal ? ch.mapToItem(root, 0, 0).x : ch.mapToItem(root, 0, 0).y;
        popouts.currentSection = root.sectionIdFor(ch);

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = items.childAt(isHorizontal ? mapToItem(items, pos, 0).x : items.width / 2, isHorizontal ? items.height / 2 : mapToItem(items, 0, pos).y);
            if (icon) {
                popouts.currentName = icon.name; // qmllint disable missing-property
                popouts.currentCenter = isHorizontal ? icon.mapToItem(null, icon.implicitWidth / 2, 0).x : icon.mapToItem(null, 0, icon.implicitHeight / 2).y;
                popouts.hasCurrent = true;
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "tray" && Config.bar.popouts.tray && !screenState.sidebar) {
            const tray = ch.item as Tray;
            const mouseMap = mapToItem(tray.expandIcon, isHorizontal ? pos : tray.implicitWidth / 2, isHorizontal ? tray.implicitHeight / 2 : pos);
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mouseMap))) {
                const traySize = isHorizontal ? tray.layout.implicitWidth : tray.layout.implicitHeight;
                const index = Math.floor(((pos - top - tray.padding * 2 + tray.spacing) / traySize) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = isHorizontal ? trayItem.mapToItem(null, trayItem.implicitWidth / 2, 0).x : trayItem.mapToItem(null, 0, trayItem.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover && Hypr.activeToplevel) {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = id.toLowerCase();
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "dock") {
            if (popouts.hasCurrent && (popouts.currentName === "dockcontext" || popouts.currentName === "activewindow"))
                return;

            const item = ch.item;
            if (item && typeof item.handleHover === "function") { // qmllint disable missing-property
                const relPos = pos - top;
                item.handleHover(relPos, isHorizontal, popouts); // qmllint disable missing-property
                return;
            }
            popouts.hasCurrent = false;
        } else if (id === "github") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = "github";
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else if (id === "spotify") {
            const item = ch.item as Item;
            if (item) {
                const relPos = pos - top;
                const inside = isHorizontal ? (relPos >= 0 && relPos <= item.implicitWidth) : (relPos >= 0 && relPos <= item.implicitHeight);
                if (inside) {
                    popouts.currentName = "spotify";
                    popouts.currentCenter = isHorizontal ? item.mapToItem(null, item.implicitWidth / 2, 0).x : (item.mapToItem(null, 0, item.implicitHeight / 2).y ?? 0);
                    popouts.hasCurrent = true;
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
            }
        } else {
            popouts.hasCurrent = false;
        }
    }

    function handleWheel(pos: real, angleDelta: point): void {
        const ch = root.entryAt(pos);
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if ((isHorizontal ? pos < screen.width / 2 : pos < screen.height / 2) && Config.bar.scrollActions.volume) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    Config.screen: screen.name

    states: [
        State {
            name: "horizontal"
            when: root.isHorizontal

            AnchorChanges {
                target: startSection
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            AnchorChanges {
                target: centerSection
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            AnchorChanges {
                target: endSection
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
            PropertyChanges {
                startSection.anchors.leftMargin: root.vPadding
                startSection.anchors.topMargin: 0
            }
            PropertyChanges {
                endSection.anchors.rightMargin: root.vPadding
                endSection.anchors.bottomMargin: 0
            }
        },
        State {
            name: "vertical"
            when: !root.isHorizontal

            AnchorChanges {
                target: startSection
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
            }
            AnchorChanges {
                target: centerSection
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
            }
            AnchorChanges {
                target: endSection
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
            }
            PropertyChanges {
                startSection.anchors.topMargin: root.vPadding
                startSection.anchors.leftMargin: 0
            }
            PropertyChanges {
                endSection.anchors.bottomMargin: root.vPadding
                endSection.anchors.rightMargin: 0
            }
        }
    ]

    EntrySection {
        id: startSection

        values: root.Config.bar.entries.start.values
    }

    EntrySection {
        id: centerSection

        values: root.Config.bar.entries.center.values
    }

    EntrySection {
        id: endSection

        values: root.Config.bar.entries.end.values
    }

    component EntrySection: GridLayout {
        id: section

        required property var values

        readonly property int count: repeater.count

        function itemAt(index: int): Item {
            return repeater.itemAt(index);
        }

        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        flow: root.isHorizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom

        columnSpacing: root.spacing
        rowSpacing: root.spacing

        Repeater {
            id: repeater

            model: ScriptModel {
                values: section.values.filter(e => e.enabled && (e.id !== "dock" || GlobalConfig.hybrid.features.dock))
            }

            delegate: EntryChooser {}
        }
    }

    component EntryChooser: DelegateChooser {
        role: "id"

        DelegateChoice {
            roleValue: "spacer"
            delegate: EntryWrapper {
                Layout.fillHeight: !root.isHorizontal && enabled
                Layout.fillWidth: root.isHorizontal && enabled
            }
        }
        DelegateChoice {
            roleValue: "logo"
            delegate: EntryWrapper {
                OsIcon {
                    objectName: "taskbarLogo"
                }
            }
        }
        DelegateChoice {
            roleValue: "workspaces"
            delegate: EntryWrapper {
                Workspaces {
                    objectName: "taskbarWorkspaces"
                    screen: root.screen
                    fullscreen: root.fullscreen
                }
            }
        }
        DelegateChoice {
            roleValue: "dock"
            delegate: EntryWrapper {
                Layout.fillWidth: true
                visible: !root.fullscreen

                Dock {
                    bar: root
                }
            }
        }
        DelegateChoice {
            roleValue: "activeWindow"
            delegate: EntryWrapper {
                ActiveWindow {
                    objectName: "taskbarActiveWindow"
                    bar: root
                    monitor: Brightness.getMonitorForScreen(root.screen)
                }
            }
        }
        DelegateChoice {
            roleValue: "tray"
            delegate: EntryWrapper {
                Tray {
                    objectName: "taskbarTray"
                }
            }
        }
        DelegateChoice {
            roleValue: "clock"
            delegate: EntryWrapper {
                Clock {
                    objectName: "taskbarClock"
                }
            }
        }
        DelegateChoice {
            roleValue: "statusIcons"
            delegate: EntryWrapper {
                StatusIcons {
                    objectName: "taskbarStatusIcons"
                }
            }
        }
        DelegateChoice {
            roleValue: "github"
            delegate: EntryWrapper {
                visible: enabled && !root.fullscreen && GithubStore.available

                GithubActivity {
                    popouts: root.popouts
                }
            }
        }
        DelegateChoice {
            roleValue: "spotify"
            delegate: EntryWrapper {
                visible: enabled && !root.fullscreen && (!Config.bar.spotify.autoHide || Players.list.length > 0)

                Spotify {
                    objectName: "taskbarSpotify"
                    popouts: root.popouts
                }
            }
        }
        DelegateChoice {
            roleValue: "power"
            delegate: EntryWrapper {
                Power {
                    objectName: "taskbarPowerButton"
                    screenState: root.screenState
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
