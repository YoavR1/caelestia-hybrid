pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

CustomMouseArea {
    id: root

    required property ScreenState screenState

    property date currentDate: screenState.dashboardDate
    readonly property int currMonth: currentDate.getMonth()
    readonly property int currYear: currentDate.getFullYear()
    readonly property int nonAnimCurrMonth: screenState.dashboardDate.getMonth()
    readonly property int nonAnimCurrYear: screenState.dashboardDate.getFullYear()

    readonly property int animDirection: screenState.dashboardDate > currentDate ? -1 : 1
    property real animTranslate
    property real animOpacity: 1

    property Item hoveredDayItem: null
    property Item lastHoveredDayItem: null
    property var lastHoveredModel: lastHoveredDayItem ? lastHoveredDayItem.model : null
    property var lastHoveredHoliday: lastHoveredDayItem ? lastHoveredDayItem.holiday : null

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth - 1, 1);
        else if (event.angleDelta.y < 0)
            screenState.dashboardDate = new Date(nonAnimCurrYear, nonAnimCurrMonth + 1, 1);
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    acceptedButtons: Qt.MiddleButton
    onClicked: root.screenState.dashboardDate = new Date()

    Anim {
        id: trOutAnim

        running: false
        target: root
        property: "animTranslate"
        to: root.Tokens.padding.extraLarge * root.animDirection
        type: Anim.FastSpatial
    }

    Behavior on currentDate {
        SequentialAnimation {
            ParallelAnimation {
                ScriptAction {
                    script: Qt.callLater(() => trOutAnim.start())
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 0
                    type: Anim.FastEffects
                }
            }
            ScriptAction {
                script: {
                    trOutAnim.complete();
                    root.animTranslate = root.Tokens.padding.extraLarge * -root.animDirection;
                }
            }
            PropertyAction {}
            ParallelAnimation {
                Anim {
                    target: root
                    property: "animTranslate"
                    to: 0
                    type: Anim.DefaultSpatial
                }
                Anim {
                    target: root
                    property: "animOpacity"
                    to: 1
                    type: Anim.DefaultEffects
                }
            }
        }
    }

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            id: monthNavigationRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall

            IconButton {
                isRound: true
                icon: "chevron_left"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.screenState.dashboardDate = new Date(root.nonAnimCurrYear, root.nonAnimCurrMonth - 1, 1)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2

                StateLayer {
                    color: Colours.palette.m3primary
                    radius: pressed ? Tokens.rounding.small : height / 2
                    disabled: {
                        const now = new Date();
                        return root.nonAnimCurrMonth === now.getMonth() && root.nonAnimCurrYear === now.getFullYear();
                    }
                    onClicked: root.screenState.dashboardDate = new Date()

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    opacity: root.animOpacity
                    transform: Translate {
                        x: root.animTranslate
                    }

                    anchors.centerIn: parent
                    text: grid.title
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).build()
                }
            }

            IconButton {
                isRound: true
                icon: "chevron_right"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).build()
                padding: Tokens.padding.small
                onClicked: root.screenState.dashboardDate = new Date(root.nonAnimCurrYear, root.nonAnimCurrMonth + 1, 1)
            }
        }

        DayOfWeekRow {
            id: daysRow

            Layout.fillWidth: true
            locale: grid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font: Tokens.font.body.builders.small.weight(Font.Medium).build()
                color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                renderType: Text.QtRendering
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight

            opacity: root.animOpacity
            transform: Translate {
                x: root.animTranslate
            }

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear

                anchors.fill: parent

                spacing: 3
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem

                    required property var model
                    property var holiday: holidayIndicator.holiday

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small

                    z: hover.hovered ? 100 : 0

                    StyledText {
                        id: text

                        anchors.centerIn: parent

                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            const dayOfWeek = dayItem.model.date.getDay();
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return Colours.palette.m3tertiary;

                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.model.month === grid.month || hover.hovered ? 1 : 0.4
                        font: Tokens.font.body.small
                        renderType: Text.QtRendering
                    }

                    Rectangle {
                        id: holidayIndicator

                        readonly property var holiday: {
                            if (!PastafarianCalendar.events)
                                return null;
                            const dateStr = Qt.formatDate(dayItem.model.date, "yyyy-MM-dd");
                            for (let i = 0; i < PastafarianCalendar.events.length; i++) {
                                if (PastafarianCalendar.events[i].day === dateStr) {
                                    return PastafarianCalendar.events[i];
                                }
                            }
                            return null;
                        }

                        anchors.top: text.bottom
                        anchors.topMargin: -2
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4
                        height: 4
                        radius: 2
                        color: Colours.palette.m3primary
                        visible: !!holiday
                    }

                    HoverHandler {
                        id: hover

                        enabled: !!holidayIndicator.holiday
                        onHoveredChanged: {
                            if (hovered) {
                                root.lastHoveredDayItem = dayItem;
                                root.hoveredDayItem = dayItem;
                            } else if (root.hoveredDayItem === dayItem) {
                                root.hoveredDayItem = null;
                            }
                        }
                    }
                }
            }

            MaterialShape {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                property Item today

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today ? today.y - Tokens.padding.extraSmall - 1 : 0

                implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Tokens.padding.extraSmall * 2 : 0
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary

                opacity: todayItem ? 1 : 0

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }
            }
        }
    }

    Item {
        id: customTooltip

        readonly property bool isActive: !!root.hoveredDayItem && !!root.hoveredDayItem.holiday

        readonly property real pillSize: root.lastHoveredDayItem ? Math.max(root.lastHoveredDayItem.implicitWidth, root.lastHoveredDayItem.implicitHeight) + Tokens.padding.extraSmall * 2 : 30
        readonly property real br: pillSize / 2

        readonly property real targetCenterX: root.lastHoveredDayItem ? root.lastHoveredDayItem.mapToItem(root, 0, 0).x + root.lastHoveredDayItem.width / 2 : 0
        readonly property real targetCenterY: root.lastHoveredDayItem ? root.lastHoveredDayItem.mapToItem(root, 0, 0).y - Tokens.padding.extraSmall - 1 + pillSize / 2 : 0

        visible: opacity > 0
        opacity: isActive ? 1 : 0
        z: 9999

        x: targetCenterX - width / 2
        y: targetCenterY - (height - br)

        width: Math.max(pillSize + 2 * (Tokens.rounding.medium + Tokens.rounding.large), holidayText.implicitWidth + Tokens.padding.large * 2)
        height: (holidayText.implicitHeight + Tokens.padding.medium * 2) + Tokens.rounding.medium + br

        scale: isActive ? 1 : 0.8
        transformOrigin: Item.Bottom

        Behavior on opacity {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        Shape {
            id: bgShape

            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: 1.0
                shadowOpacity: 0.6
                shadowColor: "black"
                autoPaddingEnabled: true
            }

            readonly property real r: Tokens.rounding.large

            readonly property real ir: Tokens.rounding.medium

            readonly property real tbh: holidayText.implicitHeight + Tokens.padding.medium * 2

            readonly property real nw: customTooltip.pillSize

            readonly property real br: customTooltip.br

            ShapePath {
                fillColor: Colours.palette.m3surfaceContainerHighest
                strokeColor: "transparent"

                startX: bgShape.r
                startY: 0

                PathLine {
                    x: bgShape.width - bgShape.r
                    y: 0
                }
                PathQuad {
                    x: bgShape.width
                    y: bgShape.r
                    controlX: bgShape.width
                    controlY: 0
                }

                PathLine {
                    x: bgShape.width
                    y: bgShape.tbh - bgShape.r
                }
                PathQuad {
                    x: bgShape.width - bgShape.r
                    y: bgShape.tbh
                    controlX: bgShape.width
                    controlY: bgShape.tbh
                }

                PathLine {
                    x: bgShape.width / 2 + bgShape.nw / 2 + bgShape.ir
                    y: bgShape.tbh
                }
                PathQuad {
                    x: bgShape.width / 2 + bgShape.nw / 2
                    y: bgShape.tbh + bgShape.ir
                    controlX: bgShape.width / 2 + bgShape.nw / 2
                    controlY: bgShape.tbh
                }

                PathLine {
                    x: bgShape.width / 2 + bgShape.nw / 2
                    y: bgShape.height - bgShape.br
                }
                PathQuad {
                    x: bgShape.width / 2
                    y: bgShape.height
                    controlX: bgShape.width / 2 + bgShape.nw / 2
                    controlY: bgShape.height
                }
                PathQuad {
                    x: bgShape.width / 2 - bgShape.nw / 2
                    y: bgShape.height - bgShape.br
                    controlX: bgShape.width / 2 - bgShape.nw / 2
                    controlY: bgShape.height
                }

                PathLine {
                    x: bgShape.width / 2 - bgShape.nw / 2
                    y: bgShape.tbh + bgShape.ir
                }
                PathQuad {
                    x: bgShape.width / 2 - bgShape.nw / 2 - bgShape.ir
                    y: bgShape.tbh
                    controlX: bgShape.width / 2 - bgShape.nw / 2
                    controlY: bgShape.tbh
                }

                PathLine {
                    x: bgShape.r
                    y: bgShape.tbh
                }
                PathQuad {
                    x: 0
                    y: bgShape.tbh - bgShape.r
                    controlX: 0
                    controlY: bgShape.tbh
                }

                PathLine {
                    x: 0
                    y: bgShape.r
                }
                PathQuad {
                    x: bgShape.r
                    y: 0
                    controlX: 0
                    controlY: 0
                }
            }
        }

        StyledText {
            id: holidayText

            text: root.lastHoveredHoliday ? root.lastHoveredHoliday.subject : ""
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Tokens.padding.medium
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Item {
            x: root.lastHoveredDayItem ? root.lastHoveredDayItem.mapToItem(root, 0, 0).x - customTooltip.x : 0
            y: root.lastHoveredDayItem ? root.lastHoveredDayItem.mapToItem(root, 0, 0).y - customTooltip.y : 0
            width: root.lastHoveredDayItem ? root.lastHoveredDayItem.width : 0
            height: root.lastHoveredDayItem ? root.lastHoveredDayItem.height : 0

            MaterialShape {
                x: (parent.width - implicitWidth) / 2
                y: -Tokens.padding.extraSmall - 1
                implicitSize: (root.lastHoveredDayItem ? Math.max(root.lastHoveredDayItem.implicitWidth, root.lastHoveredDayItem.implicitHeight) : 0) + Tokens.padding.extraSmall * 2
                shape: MaterialShape.Sunny
                color: Colours.palette.m3primary
                visible: root.lastHoveredModel && root.lastHoveredModel.today
            }

            StyledText {
                id: dupText

                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: root.lastHoveredModel ? grid.locale.toString(root.lastHoveredModel.day) : ""
                color: {
                    if (!root.lastHoveredModel)
                        return "transparent";
                    if (root.lastHoveredModel.today)
                        return Colours.palette.m3onPrimary;
                    const dayOfWeek = root.lastHoveredModel.date.getDay();
                    if (dayOfWeek === 0 || dayOfWeek === 6)
                        return Colours.palette.m3tertiary;
                    return Colours.palette.m3onSurfaceVariant;
                }
                font: Tokens.font.body.small
                renderType: Text.QtRendering
            }

            Rectangle {
                anchors.top: dupText.bottom
                anchors.topMargin: -2
                anchors.horizontalCenter: parent.horizontalCenter
                width: 4
                height: 4
                radius: 2
                color: (root.lastHoveredModel && root.lastHoveredModel.today) ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                visible: root.lastHoveredHoliday !== null
            }
        }
    }
}
