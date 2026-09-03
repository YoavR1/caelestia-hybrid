pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property bool isFetching: false
    property string errorMessage: ""

    // Bind colors at the root to avoid delegate scope resolution issues
    readonly property color cBgHigh: Colours.tPalette.m3surfaceContainerHigh

    readonly property color cBgHighest: Colours.tPalette.m3surfaceContainerHighest
    readonly property color cOnSurface: Colours.palette.m3onSurface
    readonly property color cOnSurfaceVariant: Colours.palette.m3onSurfaceVariant
    readonly property color cError: Colours.palette.m3error

    function fetchNews() {
        if (isFetching)
            return;
        isFetching = true;
        errorMessage = "";

        var xhr = new XMLHttpRequest();
        xhr.open("GET", "https://archlinux.org/feeds/news/");
        // Everything in here must go through `root`. A plain function() has its own scope,
        // so the component's properties are not visible and a bare `isFetching = false` is
        // a write to a *global*, which QML rejects at runtime:
        //   Error: Invalid write to global property "isFetching"
        // The assignments in fetchNews' own body above are fine -- a QML function body does
        // resolve against the component.
        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                root.isFetching = false;
                if (xhr.status === 200) {
                    root.parseNews(xhr.responseText);
                } else {
                    root.errorMessage = qsTr("Failed to fetch news (Status: %1)").arg(xhr.status);
                }
            }
        };
        xhr.send();
    }

    function parseNews(xmlString) {
        newsModel.clear();

        var itemRegex = /<item>([\s\S]*?)<\/item>/g;
        var titleRegex = /<title>(.*?)<\/title>/;
        var linkRegex = /<link>(.*?)<\/link>/;
        var dateRegex = /<pubDate>(.*?)<\/pubDate>/;

        var match;
        while ((match = itemRegex.exec(xmlString)) !== null) {
            var itemContent = match[1];

            var titleMatch = titleRegex.exec(itemContent);
            var linkMatch = linkRegex.exec(itemContent);
            var dateMatch = dateRegex.exec(itemContent);

            if (titleMatch && linkMatch && dateMatch) {
                // Remove CDATA if present or unescape basic HTML entities
                var title = titleMatch[1].replace(/<!\[CDATA\[(.*?)\]\]>/g, "$1").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#039;/g, "'");
                var dateStr = dateMatch[1];

                // Format date nicely
                var dateObj = new Date(dateStr);
                var formattedDate = dateObj.toLocaleDateString();
                if (formattedDate === "Invalid Date")
                    formattedDate = dateStr;

                newsModel.append({
                    "title": title,
                    "link": linkMatch[1],
                    "date": formattedDate
                });
            }
        }

        if (newsModel.count === 0) {
            errorMessage = qsTr("No news articles found.");
        }
    }

    Component.onCompleted: fetchNews()

    ListModel {
        id: newsModel
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Arch Linux News")
                font: Tokens.font.title.medium
                color: root.cOnSurface
            }

            IconButton {
                icon: "refresh"
                onClicked: root.fetchNews()
            }
        }

        // Error message
        StyledText {
            Layout.fillWidth: true
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: root.cError
            wrapMode: Text.WordWrap
        }

        // Loading Indicator
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.isFetching && newsModel.count === 0

            StyledText {
                anchors.centerIn: parent
                text: qsTr("Fetching latest news...")
                color: root.cOnSurfaceVariant
            }
        }

        // List
        ListView {
            id: newsListView

            Layout.fillWidth: true
            Layout.fillHeight: true
            model: newsModel
            spacing: Tokens.spacing.small
            clip: true
            visible: !root.isFetching || newsModel.count > 0

            ScrollBar.vertical: StyledScrollBar {
                flickable: newsListView
            }

            delegate: StyledRect {
                id: delegateItem

                required property string title
                required property string link
                required property string date

                width: ListView.view.width
                implicitHeight: col.implicitHeight + Tokens.padding.medium * 2
                radius: Tokens.rounding.medium

                color: ma.containsMouse ? root.cBgHighest : root.cBgHigh

                MouseArea {
                    id: ma

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally(delegateItem.link)
                }

                ColumnLayout {
                    id: col

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.extraSmall

                    StyledText {
                        Layout.fillWidth: true
                        text: delegateItem.title
                        font: Tokens.font.label.large
                        color: root.cOnSurface
                        wrapMode: Text.WordWrap
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: delegateItem.date
                        font: Tokens.font.body.small
                        color: root.cOnSurfaceVariant
                    }
                }
            }
        }
    }
}
