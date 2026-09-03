pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components

Item {
    id: root

    property real blurAmount: skipIntroAnimation ? 0.0 : 1.0
    property bool skipIntroAnimation: false

    property real star1Opacity: skipIntroAnimation ? 1.0 : 0.0
    property real star2Opacity: skipIntroAnimation ? 1.0 : 0.0
    property real star3Opacity: skipIntroAnimation ? 1.0 : 0.0

    property real star1Scale: skipIntroAnimation ? 1.0 : 0.0
    property real star2Scale: skipIntroAnimation ? 1.0 : 0.0
    property real star3Scale: skipIntroAnimation ? 1.0 : 0.0

    readonly property alias topShape: topShape
    readonly property alias bottomShape: bottomShape
    readonly property alias star1: star1
    readonly property alias star2: star2
    readonly property alias star3: star3

    signal animationCompleted

    implicitWidth: 128
    implicitHeight: 153.8

    Item {
        id: logo

        readonly property real designWidth: 128
        readonly property real designHeight: 153.8

        property color topColour: "#EBF4FF"
        property color bottomColour: "#FFFFFF"
        property color starColour: "#6AE5E1"

        implicitWidth: designWidth
        implicitHeight: designHeight

        transformOrigin: Item.Center
        scale: root.skipIntroAnimation ? 1.0 : 0.0
        opacity: root.skipIntroAnimation ? 1.0 : 0.0
        rotation: 0.0

        layer.enabled: root.blurAmount > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blurAmount
            blurMax: 60
        }

        Component.onCompleted: {
            root.star1.opacity = Qt.binding(() => root.star1Opacity);
            root.star1.scale = Qt.binding(() => root.star1Scale);
            root.star2.opacity = Qt.binding(() => root.star2Opacity);
            root.star2.scale = Qt.binding(() => root.star2Scale);
            root.star3.opacity = Qt.binding(() => root.star3Opacity);
            root.star3.scale = Qt.binding(() => root.star3Scale);
        }

        Behavior on topColour {
            CAnim {}
        }

        Behavior on bottomColour {
            CAnim {}
        }

        Behavior on starColour {
            CAnim {}
        }

        Shape {
            id: topShape

            anchors.centerIn: parent
            width: logo.designWidth
            height: logo.designHeight
            scale: Math.min(logo.width / width, logo.height / height)
            transformOrigin: Item.Center
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: logo.topColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M47.474182 3.813545C51.044545 2.290673 54.665273 1.054265 58.310545 0.094006C60.981455 -0.609544 62.593091 2.802400 60.671091 4.785891C39.451273 26.684727 32.200182 59.995455 44.913636 89.803091C57.627091 119.610364 86.687636 137.433455 117.180545 137.276000C119.942364 137.261636 121.289455 140.786364 118.933091 142.227091C115.716909 144.193455 112.318364 145.950909 108.747818 147.473818C69.077091 164.394182 23.201091 145.951273 6.280836 106.280545C-10.639436 66.609818 7.803418 20.733818 47.474182 3.813545Z"
                }
            }
        }

        Shape {
            id: bottomShape

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: logo.bottomColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M53.987818 50.725818C53.811455 50.767636 53.636909 50.811273 53.462364 50.854909C53.647818 50.809455 53.822364 50.765818 53.987818 50.725818Z"
                }
            }
        }

        Shape {
            id: star1

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.0

            ShapePath {
                fillColor: logo.starColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M87.655636 26.065091C87.061091 30.299636 84.152000 43.170545 70.657455 44.748727C70.484727 44.768727 70.484727 45.016000 70.657455 45.036000C84.152000 46.614182 87.064727 59.486909 87.659273 63.719636C87.682909 63.888727 87.926545 63.888727 87.950182 63.719636C88.544727 59.485091 91.453818 46.614182 104.948364 45.036000C105.121091 45.016000 105.121091 44.768727 104.948364 44.748727C91.453818 43.170545 88.541091 30.297818 87.946545 26.065091C87.922909 25.896000 87.679273 25.896000 87.655636 26.065091Z"
                }
            }
        }

        Shape {
            id: star2

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.0

            ShapePath {
                fillColor: logo.starColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M118.639091 57.443273C118.195455 60.063273 116.440909 66.288727 109.730000 67.337818C109.562727 67.363273 109.562727 67.597818 109.730000 67.623273C116.440909 68.672364 118.197273 74.899636 118.640909 77.517818C118.668182 77.679636 118.902727 77.679636 118.930000 77.517818C119.373636 74.897818 121.128182 68.672364 127.839091 67.623273C128.006364 67.597818 128.006364 67.363273 127.839091 67.337818C121.128182 66.288727 119.371818 60.061455 118.928182 57.443273C118.900909 57.281455 118.666364 57.281455 118.639091 57.443273Z"
                }
            }
        }

        Shape {
            id: star3

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.0

            ShapePath {
                fillColor: logo.starColour
                strokeColor: "transparent"

                PathSvg {
                    path: "M98.111455 77.694000C97.727818 79.744909 96.360545 84.099455 91.602364 84.957636C91.440545 84.986727 91.440545 85.212182 91.602364 85.241273C96.360545 86.099455 97.729636 90.452182 98.113273 92.504909C98.142364 92.664909 98.371455 92.664909 98.402364 92.504909C98.786000 90.454000 100.153273 86.099455 104.911455 85.241273C105.073273 85.212182 105.073273 84.986727 104.911455 84.957636C100.153273 84.099455 98.784182 79.746727 98.400545 77.694000C98.371455 77.534000 98.142364 77.534000 98.111455 77.694000Z"
                }
            }
        }
    }

    SequentialAnimation {
        running: !root.skipIntroAnimation
        onFinished: root.animationCompleted()

        ParallelAnimation {
            SequentialAnimation {
                NumberAnimation {
                    target: logo
                    property: "rotation"
                    from: 0
                    to: 750
                    duration: 1000
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: logo
                    property: "rotation"
                    from: 750
                    to: 710
                    duration: 300
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: logo
                    property: "rotation"
                    from: 710
                    to: 725
                    duration: 350
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: logo
                    property: "rotation"
                    from: 725
                    to: 720
                    duration: 250
                    easing.type: Easing.OutQuad
                }

                ScriptAction {
                    script: logo.rotation = 0
                }
            }

            SequentialAnimation {
                NumberAnimation {
                    target: logo
                    property: "scale"
                    from: 0.0
                    to: 1.08
                    duration: 1000
                    easing.type: Easing.OutCubic
                }

                NumberAnimation {
                    target: logo
                    property: "scale"
                    from: 1.08
                    to: 0.96
                    duration: 200
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: logo
                    property: "scale"
                    from: 0.96
                    to: 1.0
                    duration: 250
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.05
                }
            }

            NumberAnimation {
                target: logo
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 600
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                target: root
                property: "blurAmount"
                from: 1.0
                to: 0.0
                duration: 900
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 1100
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "star1Opacity"
                        from: 0.0
                        to: 1.0
                        duration: 700
                        easing.type: Easing.InOutQuad
                    }

                    SequentialAnimation {
                        NumberAnimation {
                            target: root
                            property: "star1Scale"
                            from: 0.0
                            to: 1.08
                            duration: 500
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            target: root
                            property: "star1Scale"
                            from: 1.08
                            to: 1.0
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 1250
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "star2Opacity"
                        from: 0.0
                        to: 1.0
                        duration: 700
                        easing.type: Easing.InOutQuad
                    }

                    SequentialAnimation {
                        NumberAnimation {
                            target: root
                            property: "star2Scale"
                            from: 0.0
                            to: 1.08
                            duration: 500
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            target: root
                            property: "star2Scale"
                            from: 1.08
                            to: 1.0
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 1400
                }

                ParallelAnimation {
                    NumberAnimation {
                        target: root
                        property: "star3Opacity"
                        from: 0.0
                        to: 1.0
                        duration: 700
                        easing.type: Easing.InOutQuad
                    }

                    SequentialAnimation {
                        NumberAnimation {
                            target: root
                            property: "star3Scale"
                            from: 0.0
                            to: 1.08
                            duration: 500
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            target: root
                            property: "star3Scale"
                            from: 1.08
                            to: 1.0
                            duration: 400
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        running: true
        loops: Animation.Infinite

        PauseAnimation {
            duration: 2500
        }

        ParallelAnimation {
            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: root.star1
                    property: "y"
                    from: root.star1.y
                    to: root.star1.y - 5
                    duration: 2500
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: root.star1
                    property: "y"
                    from: root.star1.y - 5
                    to: root.star1.y
                    duration: 2500
                    easing.type: Easing.InOutQuad
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: root.star2
                    property: "y"
                    from: root.star2.y
                    to: root.star2.y + 5
                    duration: 3000
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: root.star2
                    property: "y"
                    from: root.star2.y + 5
                    to: root.star2.y
                    duration: 3000
                    easing.type: Easing.InOutQuad
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: root.star3
                    property: "y"
                    from: root.star3.y
                    to: root.star3.y - 5
                    duration: 2800
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: root.star3
                    property: "y"
                    from: root.star3.y - 5
                    to: root.star3.y
                    duration: 2800
                    easing.type: Easing.InOutQuad
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: root.star1
                    property: "scale"
                    from: 1.0
                    to: 1.08
                    duration: 2500
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: root.star1
                    property: "scale"
                    from: 1.08
                    to: 1.0
                    duration: 2500
                    easing.type: Easing.InOutQuad
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: root.star2
                    property: "scale"
                    from: 1.0
                    to: 1.12
                    duration: 3000
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: root.star2
                    property: "scale"
                    from: 1.12
                    to: 1.0
                    duration: 3000
                    easing.type: Easing.InOutQuad
                }
            }

            SequentialAnimation {
                loops: Animation.Infinite

                NumberAnimation {
                    target: root.star3
                    property: "scale"
                    from: 1.0
                    to: 1.08
                    duration: 2800
                    easing.type: Easing.InOutQuad
                }

                NumberAnimation {
                    target: root.star3
                    property: "scale"
                    from: 1.08
                    to: 1.0
                    duration: 2800
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
}
