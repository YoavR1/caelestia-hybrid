pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import M3Shapes
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

Item {
    id: root

    property string source: Wallpapers.current
    property Item current: null
    property bool completed
    property string settledSource: ""
    property var screen: null
    property bool weActive: false
    property string weDir: ""

    readonly property string currentSchemeName: (Colours.showPreview ? Colours["previewScheme"] : Colours.scheme) || ""

    readonly property string currentVariantName: (Colours.showPreview ? Colours["previewVariant"] : Colours.variant) || ""

    readonly property string currentFlavourName: (Colours.showPreview ? Colours["previewFlavour"] : Colours.flavour) || ""

    readonly property bool isDynamicScheme: root.currentSchemeName.startsWith("dynamic")

    readonly property bool isDynamicMonochrome: root.isDynamicScheme && root.currentVariantName === "monochrome"

    readonly property bool shouldRecolor: !!(Config.background && Config.background["wallpaperRecolor"]) && (!root.isDynamicScheme || root.isDynamicMonochrome)

    readonly property var shapes: [MaterialShape.Circle, MaterialShape.Square, MaterialShape.Diamond, MaterialShape.ClamShell, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Cookie6Sided]

    function checkWE(path: string): void {
        if (!path) {
            weActive = false;
            return;
        }
        let dir = path.substring(0, path.lastIndexOf('/'));
        let projJson = dir + "/project.json";
        if (CUtils.fileExists(projJson)) {
            weDir = dir;
            weActive = true;
        } else {
            weActive = false;
        }
    }

    function toFileUrl(path) {
        if (!path)
            return "";
        const clean = String(path).trim();
        if (clean.indexOf("file://") === 0)
            return clean;
        if (clean[0] === "/")
            return "file://" + clean;
        return Qt.resolvedUrl(clean);
    }

    function applySourceChange() {
        if (source === settledSource && root.current && root.current.state === "active") {
            return;
        }

        settledSource = source;

        if (!settledSource) {
            one.state = "inactive";
            two.state = "inactive";
            current = null;
            return;
        }

        let nextLayer = null;
        let prevLayer = null;

        if (one.state === "active") {
            prevLayer = one;
            nextLayer = two;
        } else if (two.state === "active") {
            prevLayer = two;
            nextLayer = one;
        } else {
            prevLayer = null;
            nextLayer = one;
        }

        if (nextLayer.state === "background") {
            nextLayer.state = "inactive";
        }

        if (prevLayer) {
            prevLayer.state = "background";
        }

        nextLayer.path = settledSource;
        nextLayer.state = "active";
        root.current = nextLayer;
    }

    onSourceChanged: {
        checkWE(source);
        coalesceTimer.restart();
    }

    Component.onCompleted: {
        if (source) {
            checkWE(source);
            settledSource = source;
            one.path = settledSource;
            one.state = "active";
            root.current = one;
            completed = true;
        } else {
            completed = true;
        }
    }

    Timer {
        id: coalesceTimer

        interval: 80
        repeat: false
        onTriggered: root.applySourceChange()
    }

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: root.completed && !root.source
        sourceComponent: StyledRect {
            color: (Colours.palette && Colours.palette.m3surfaceContainer) || "transparent"
        }
    }

    Img {
        id: one
    }

    Img {
        id: two
    }

    component Img: Item {
        id: img

        property string path: ""

        readonly property bool isGif: img.verifiedPath.toLowerCase().endsWith(".gif")

        readonly property bool isVideo: Wallpapers.isVideo(path)

        readonly property bool animsEnabled: !!Wallpapers.enableAnimation

        readonly property string verifiedPath: path || ""

        readonly property int fadeMs: 400

        property bool renderActive: false

        readonly property bool isPlayerPlaying: !!(videoChannelLoader.item && videoChannelLoader.item["playing"]) // qmllint disable missing-property

        readonly property real maxRadius: Math.sqrt(width * width + height * height)

        property real maskRadius: 0

        property int currentShape: MaterialShape.Circle

        readonly property bool hasReadyContent: thumbImg.status === Image.Ready || isPlayerPlaying || gifImg.status === Image.Ready

        readonly property bool needsMask: animsEnabled && img.z === 1 && hasReadyContent && img.maskRadius < (img.maxRadius - 1.5) && !!maskLoader.item

        state: "inactive"

        anchors.fill: parent
        opacity: 0

        states: [
            State {
                name: "active"

                PropertyChanges {
                    img.opacity: 1
                    img.z: 1
                    img.renderActive: true
                }
            },
            State {
                name: "background"

                PropertyChanges {
                    img.opacity: 1
                    img.z: 0
                    img.renderActive: true
                }
            },
            State {
                name: "inactive"

                PropertyChanges {
                    img.opacity: 0
                    img.z: 0
                    img.renderActive: false
                }
            }
        ]

        transitions: [
            Transition {
                from: "inactive"
                to: "active"
                enabled: root.completed && !img.animsEnabled

                NumberAnimation {
                    property: "opacity"
                    duration: img.fadeMs
                    easing.type: Easing.InOutQuad
                }
            }
        ]

        onStateChanged: {
            if (state === "active") {
                cleanupTimer.stop();
                if (animsEnabled && root.completed) {
                    maskRadius = 0;
                    maskAnim.restart();
                } else {
                    maskRadius = maxRadius;
                }
            } else if (state === "background") {
                cleanupTimer.restart();
                if (animsEnabled) {
                    maskRadius = maxRadius;
                    currentShape = root.shapes[Math.floor(Math.random() * root.shapes.length)];
                }
            } else {
                cleanupTimer.stop();
            }
        }

        onMaxRadiusChanged: {
            if (!root.completed || (!maskAnim.running && (state === "active" || state === "background"))) {
                maskRadius = maxRadius;
            }
        }

        Component.onCompleted: maskRadius = maxRadius

        Timer {
            id: cleanupTimer

            interval: (img.animsEnabled && root.completed) ? 2600 : (img.fadeMs + 20)
            repeat: false
            onTriggered: img.state = "inactive"
        }

        Loader {
            id: maskLoader

            anchors.fill: parent
            active: img.animsEnabled

            sourceComponent: Item {
                id: maskContainer

                readonly property Item maskSource: maskSourceItem

                anchors.fill: parent

                Item {
                    id: maskWrapper

                    anchors.fill: parent
                    visible: img.needsMask

                    MaterialShape {
                        anchors.centerIn: parent
                        width: img.maxRadius * 2
                        height: img.maxRadius * 2
                        shape: img.currentShape
                        color: "white"
                        scale: img.maxRadius > 0 ? (img.maskRadius / img.maxRadius) : 0
                    }
                }

                ShaderEffectSource {
                    id: maskSourceItem

                    sourceItem: maskWrapper
                    anchors.fill: parent
                    hideSource: true
                    live: img.needsMask
                    visible: false
                }
            }
        }

        Item {
            id: contentItem

            anchors.fill: parent
            opacity: root.weActive ? 0 : 1

            layer.enabled: img.needsMask || (root.shouldRecolor && img.renderActive)

            layer.effect: MultiEffect {
                maskEnabled: img.needsMask

                maskSource: maskLoader.item ? maskLoader.item.maskSource : null // qmllint disable missing-property

                shadowEnabled: img.needsMask && !img.isVideo
                shadowColor: "black"
                shadowBlur: 1.0
                shadowVerticalOffset: 15
                shadowHorizontalOffset: 5

                saturation: (root.shouldRecolor && root.isDynamicMonochrome) ? -1 : 0
                colorization: (root.shouldRecolor && !root.isDynamicMonochrome) ? (Config.background ? Config.background["wallpaperRecolorStrength"] : 0) : 0
                colorizationColor: (Colours.palette && Colours.palette.m3primary) || "transparent"

                contrast: (root.shouldRecolor && root.currentFlavourName === "hard") ? 0.45 : 0.0

                Behavior on saturation {
                    enabled: img.animsEnabled && img.state === "active"

                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
                Behavior on colorization {
                    enabled: img.animsEnabled && img.state === "active"

                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
                Behavior on contrast {
                    enabled: img.animsEnabled && img.state === "active"

                    Anim {
                        type: Anim.DefaultEffects
                    }
                }
                Behavior on colorizationColor {
                    enabled: img.animsEnabled && img.state === "active"

                    CAnim {}
                }
            }

            CachingAnimatedImage {
                id: gifImg

                anchors.fill: parent
                path: img.verifiedPath
                source: img.verifiedPath || ""
                playing: !WallpaperPauser.paused
                visible: img.isGif && !img.isVideo
                asynchronous: true

                onStatusChanged: {
                    if (status === Image.Ready && img.isGif && img.verifiedPath === root.settledSource)
                        root.current = img;
                }
            }

            CachingImage {
                id: thumbImg

                anchors.fill: parent
                path: img.verifiedPath
                source: {
                    if (!img.verifiedPath)
                        return "";
                    if (img.isVideo) {
                        const thumb = Wallpapers.getWallpaperThumb(img.verifiedPath, Wallpapers.cacheBuster);
                        return typeof thumb === "string" ? thumb : "";
                    }
                    return img.verifiedPath;
                }

                visible: (!img.isVideo && !img.isGif) || (img.isVideo && !img.isPlayerPlaying && videoChannelLoader.status !== Loader.Ready)
                asynchronous: true

                onStatusChanged: {
                    if (status === Image.Ready && !img.isVideo && !img.isGif && img.verifiedPath === root.settledSource)
                        root.current = img;
                }
            }

            Loader {
                id: videoChannelLoader

                anchors.fill: parent
                asynchronous: true

                active: GlobalConfig.hybrid.features.videoWallpaper && img.isVideo && img.verifiedPath !== "" && img.renderActive
                source: "VideoWallpaper.qml"

                onLoaded: {
                    if (item && img.verifiedPath !== "") {
                        item.videoSource = root.toFileUrl(img.verifiedPath);
                        item.autoStart = !WallpaperPauser.paused;
                    }
                }

                Timer {
                    id: resumeTimer

                    interval: 150
                    repeat: false
                    onTriggered: {
                        if (videoChannelLoader.item && img.isVideo && !WallpaperPauser.paused && img.state === "active") {
                            videoChannelLoader.item["stop"](); // qmllint disable missing-property
                            videoChannelLoader.item["play"](); // qmllint disable missing-property
                        }
                    }
                }

                Connections {
                    function onPausedChanged() {
                        if (videoChannelLoader.item && img.isVideo) {
                            if (WallpaperPauser.paused) {
                                resumeTimer.stop();
                                videoChannelLoader.item["pause"](); // qmllint disable missing-property
                            } else {
                                if (img.state === "active") {
                                    resumeTimer.restart();
                                }
                            }
                        }
                    }

                    target: WallpaperPauser
                    ignoreUnknownSignals: true
                    enabled: img.isVideo && videoChannelLoader.active
                }
            }
        }

        Anim {
            id: maskAnim

            target: img
            property: "maskRadius"
            from: 0
            to: img.maxRadius
            type: Anim.Emphasized
            duration: 2500
        }
    }
}
