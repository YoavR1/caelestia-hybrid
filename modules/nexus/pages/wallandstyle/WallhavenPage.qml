import QtQuick
import qs.modules.dashboard
import qs.modules.nexus.common

PageBase {
    title: qsTr("Wallhaven")
    isSubPage: true
    scrollable: false

    WallhavenTab {
        anchors.fill: parent
    }
}
