pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.nexus

Singleton {
    id: root

    // The most recently created settings window, while it lives. Windows null this on
    // destruction, so it is never a dangling pointer.
    property var current: null

    function create(parent: Item, props: var): void {
        root.current = nexusComp.createObject(parent ?? dummy, props);
    }

    // Open the settings at a given page, reusing the window that is already open rather
    // than stacking another one on top of it -- which is what a settings window should do,
    // and what stops sixteen of them piling up.
    function openPage(page: int): void {
        if (root.current)
            root.current.page = page;
        else
            root.create(null, {
                page
            });
    }

    QtObject {
        id: dummy
    }

    Component {
        id: nexusComp

        FloatingWindow {
            id: win

            // Which settings page to land on. Set through WindowFactory.create()'s props,
            // which is how the `nexus openPage` IPC call reaches it.
            property int page: 0

            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false

            onVisibleChanged: {
                if (!visible)
                    destroy();
            }

            Component.onDestruction: {
                if (WindowFactory.current === win)
                    WindowFactory.current = null;
            }

            implicitWidth: nexus.implicitWidth
            implicitHeight: nexus.implicitHeight

            minimumSize.width: contentItem.Tokens.sizes.nexus.minWidth
            minimumSize.height: contentItem.Tokens.sizes.nexus.minHeight

            contentItem.Config.screen: screen.name
            contentItem.Tokens.screen: screen.name

            title: qsTr("Nexus — %1").arg(PageRegistry.pages[nexus.nState.currentPageIdx]?.label ?? "")

            Nexus {
                id: nexus

                anchors.fill: parent
                nState.screen: win.screen
                nState.isWindow: true
                nState.currentPageIdx: win.page
                onClose: win.destroy()
            }

            Behavior on color {
                CAnim {}
            }
        }
    }
}
