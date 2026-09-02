import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Window & Lock Sizes")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: TokenConfig.appearance.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("Lock Screen")
        }

        SliderRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Height Multiplier")
            value: TokenConfig.sizes.lock.heightMult
            valueLabel: value.toFixed(2)
            showReset: true
            onMoved: v => TokenConfig.sizes.lock.heightMult = v
            onReset: {
                TokenConfig.sizes.lock.heightMult = TokenConfig.defaults().sizes.lock.heightMult;
                TokenConfig.sizes.lock.resetOption("heightMult");
            }
        }

        SliderRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Aspect Ratio")
            value: (TokenConfig.sizes.lock.ratio - 1.0) / 1.5
            valueLabel: (1.0 + value * 1.5).toFixed(2)
            showReset: true
            onMoved: v => TokenConfig.sizes.lock.ratio = 1.0 + v * 1.5
            onReset: {
                TokenConfig.sizes.lock.ratio = TokenConfig.defaults().sizes.lock.ratio;
                TokenConfig.sizes.lock.resetOption("ratio");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Center Card Width")
            value: TokenConfig.sizes.lock.centerWidth
            from: 200
            to: 1000
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.lock.centerWidth = v
            onReset: {
                TokenConfig.sizes.lock.centerWidth = TokenConfig.defaults().sizes.lock.centerWidth;
                TokenConfig.sizes.lock.resetOption("centerWidth");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Forecast Item Width")
            value: TokenConfig.sizes.lock.forecastItemWidth
            from: 20
            to: 100
            stepSize: 2
            showReset: true
            onMoved: v => TokenConfig.sizes.lock.forecastItemWidth = v
            onReset: {
                TokenConfig.sizes.lock.forecastItemWidth = TokenConfig.defaults().sizes.lock.forecastItemWidth;
                TokenConfig.sizes.lock.resetOption("forecastItemWidth");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Large Logo Width")
            value: TokenConfig.sizes.lock.largeLogoWidth
            from: 100
            to: 500
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.lock.largeLogoWidth = v
            onReset: {
                TokenConfig.sizes.lock.largeLogoWidth = TokenConfig.defaults().sizes.lock.largeLogoWidth;
                TokenConfig.sizes.lock.resetOption("largeLogoWidth");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Large Font Width")
            value: TokenConfig.sizes.lock.largeFontWidth
            from: 100
            to: 600
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.lock.largeFontWidth = v
            onReset: {
                TokenConfig.sizes.lock.largeFontWidth = TokenConfig.defaults().sizes.lock.largeFontWidth;
                TokenConfig.sizes.lock.resetOption("largeFontWidth");
            }
        }

        SectionHeader {
            text: qsTr("Nexus Settings Window")
        }

        SliderRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Height Multiplier")
            value: TokenConfig.sizes.nexus.heightMult
            valueLabel: value.toFixed(2)
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.heightMult = v
            onReset: {
                TokenConfig.sizes.nexus.heightMult = TokenConfig.defaults().sizes.nexus.heightMult;
                TokenConfig.sizes.nexus.resetOption("heightMult");
            }
        }

        SliderRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Aspect Ratio")
            value: (TokenConfig.sizes.nexus.ratio - 1.0) / 1.5
            valueLabel: (1.0 + value * 1.5).toFixed(2)
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.ratio = 1.0 + v * 1.5
            onReset: {
                TokenConfig.sizes.nexus.ratio = TokenConfig.defaults().sizes.nexus.ratio;
                TokenConfig.sizes.nexus.resetOption("ratio");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Minimum Width")
            value: TokenConfig.sizes.nexus.minWidth
            from: 400
            to: 1200
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.minWidth = v
            onReset: {
                TokenConfig.sizes.nexus.minWidth = TokenConfig.defaults().sizes.nexus.minWidth;
                TokenConfig.sizes.nexus.resetOption("minWidth");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Minimum Height")
            value: TokenConfig.sizes.nexus.minHeight
            from: 300
            to: 900
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.minHeight = v
            onReset: {
                TokenConfig.sizes.nexus.minHeight = TokenConfig.defaults().sizes.nexus.minHeight;
                TokenConfig.sizes.nexus.resetOption("minHeight");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Max Navigation Width")
            value: TokenConfig.sizes.nexus.maxNavWidth
            from: 200
            to: 800
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.maxNavWidth = v
            onReset: {
                TokenConfig.sizes.nexus.maxNavWidth = TokenConfig.defaults().sizes.nexus.maxNavWidth;
                TokenConfig.sizes.nexus.resetOption("maxNavWidth");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Max Content Width")
            value: TokenConfig.sizes.nexus.maxContentWidth
            from: 400
            to: 1200
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.maxContentWidth = v
            onReset: {
                TokenConfig.sizes.nexus.maxContentWidth = TokenConfig.defaults().sizes.nexus.maxContentWidth;
                TokenConfig.sizes.nexus.resetOption("maxContentWidth");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Popup Width")
            value: TokenConfig.sizes.nexus.popupWidth
            from: 150
            to: 500
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.nexus.popupWidth = v
            onReset: {
                TokenConfig.sizes.nexus.popupWidth = TokenConfig.defaults().sizes.nexus.popupWidth;
                TokenConfig.sizes.nexus.resetOption("popupWidth");
            }
        }

        SectionHeader {
            text: qsTr("Window Information Overlay")
        }

        SliderRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Height Multiplier")
            value: TokenConfig.sizes.winfo.heightMult
            valueLabel: value.toFixed(2)
            showReset: true
            onMoved: v => TokenConfig.sizes.winfo.heightMult = v
            onReset: {
                TokenConfig.sizes.winfo.heightMult = TokenConfig.defaults().sizes.winfo.heightMult;
                TokenConfig.sizes.winfo.resetOption("heightMult");
            }
        }

        StepperRow {
            Layout.topMargin: TokenConfig.appearance.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Details Pane Width")
            value: TokenConfig.sizes.winfo.detailsWidth
            from: 200
            to: 800
            stepSize: 10
            showReset: true
            onMoved: v => TokenConfig.sizes.winfo.detailsWidth = v
            onReset: {
                TokenConfig.sizes.winfo.detailsWidth = TokenConfig.defaults().sizes.winfo.detailsWidth;
                TokenConfig.sizes.winfo.resetOption("detailsWidth");
            }
        }
    }
}
