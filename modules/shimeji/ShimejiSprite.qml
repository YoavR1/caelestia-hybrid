import QtQuick

Item {
    id: root

    required property var screenSize
    required property var borderThickness
    required property string imgPath
    property real floorOffset: 0

    readonly property real floorY: screenSize.height - 128 - borderThickness - floorOffset
    readonly property real minX: 0
    readonly property real maxX: screenSize.width - 128
    readonly property real maxY: screenSize.height - 128 - floorOffset

    property real vx: 0
    property real vy: 0
    readonly property real gravity: 2
    readonly property real friction: 0.85

    property bool onGround: false
    property bool dragging: false
    property point dragOffset
    property real lastX: 0
    property real lastY: 0
    property real dragVx: 0
    property real dragVy: 0
    property int walkTarget: -1

    property string currentAnim: "idle"
    property int frameIndex: 0
    property bool facingRight: true

    function pickIdle() {
        const roll = Math.random();
        if (roll < 0.35)
            currentAnim = "idle";
        else if (roll < 0.55)
            currentAnim = "lookUp";
        else if (roll < 0.75)
            currentAnim = "dangle";
        else
            currentAnim = "sleep";
        frameIndex = 0;
    }

    function walkRandom() {
        const margin = 100;
        walkTarget = margin + Math.random() * (screenSize.width - 128 - margin * 2);
        currentAnim = "walk";
        facingRight = walkTarget > root.x;
        frameIndex = 0;
    }

    function animFrame(anim, index) {
        const frames = {
            idle: ["shime1.png"],
            lookUp: ["shime26.png"],
            dangle: ["shime31.png", "shime32.png", "shime31.png", "shime33.png"],
            layDown: ["shime21.png"],
            sleep: ["shime20.png", "shime21.png"],
            walk: ["shime1.png", "shime2.png", "shime1.png", "shime3.png"],
            stand: ["shime1.png"],
            eat: ["shime26.png", "shime15.png", "shime27.png", "shime16.png", "shime28.png", "shime17.png", "shime29.png", "shime11.png"]
        };
        const list = frames[anim];
        return list ? list[index % list.length] : "";
    }

    function tick(dt) {
        if (dragging)
            return;

        const timeScale = dt / 0.030;

        if (!onGround) {
            vy += gravity * timeScale;
            vx *= Math.pow(0.98, timeScale);
        } else if (Math.abs(vx) > 0.1) {
            vx *= Math.pow(0.3, timeScale);
            if (Math.abs(vx) < 0.5)
                vx = 0;
        }

        if (walkTarget >= 0) {
            const dx = walkTarget - root.x;
            if (Math.abs(dx) < 5) {
                walkTarget = -1;
                vx = 0;
                pickIdle();
            } else {
                vx = Math.sign(dx) * 2.5;
                facingRight = vx > 0;
                currentAnim = "walk";
            }
        }

        root.x += vx * timeScale;
        root.y += vy * timeScale;

        if (root.x < minX) {
            root.x = minX;
            vx = Math.abs(vx) * 0.9;
        } else if (root.x > maxX) {
            root.x = maxX;
            vx = -Math.abs(vx) * 0.9;
        }

        if (root.y > floorY) {
            root.y = floorY;
            vy = -vy * 0.6;
            if (vy >= 0 && Math.abs(vy) < 2) {
                vy = 0;
                onGround = true;
                vx = 0;
                currentAnim = "idle";
                if (walkTarget < 0 && Math.random() < 0.1 * timeScale) {
                    walkRandom();
                }
            } else if (vy < 0) {
                onGround = false;
            }
        } else if (root.y < 0) {
            root.y = 0;
            vy = Math.abs(vy) * 0.6;
        }
    }

    x: 0
    y: floorY
    width: 128
    height: 128

    Component.onCompleted: {
        const margin = 50;
        x = margin + Math.random() * (screenSize.width - 128 - margin * 2);
        y = floorY;
        onGround = true;
        vx = 0;
        vy = 0;
        pickIdle();
    }

    onDraggingChanged: {
        if (!dragging) {
            vx = dragVx * 2;
            vy = dragVy > 0 ? dragVy * 2 : dragVy * 2;
            if (Math.abs(vx) < 1)
                vx = 0;
            if (Math.abs(vy) < 1)
                vy = 0;
            onGround = false;
            pickIdle();
        }
    }

    MouseArea {
        id: grabArea

        x: 0
        y: 0
        width: 128
        height: 128
        hoverEnabled: false
        propagateComposedEvents: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            root.dragging = true;
            root.currentAnim = "idle";
            root.walkTarget = -1;
            root.dragOffset = Qt.point(mouse.x, mouse.y);
            root.lastX = root.x;
            root.lastY = root.y;
            root.dragVx = 0;
            root.dragVy = 0;
            root.vx = 0;
            root.vy = 0;
        }

        onPositionChanged: mouse => {
            if (root.dragging) {
                const newX = Math.max(root.minX, Math.min(root.maxX, root.x + mouse.x - root.dragOffset.x));
                const newY = Math.max(0, Math.min(root.maxY, root.y + mouse.y - root.dragOffset.y));
                root.dragVx = newX - root.lastX;
                root.dragVy = newY - root.lastY;
                root.lastX = newX;
                root.lastY = newY;
                root.x = newX;
                root.y = newY;
            }
        }

        onReleased: root.dragging = false
    }

    Image {
        id: spriteImage

        anchors.fill: parent
        source: {
            const fn = root.animFrame(root.currentAnim, root.frameIndex);
            return fn ? "file://" + root.imgPath + fn : "";
        }
        sourceSize.width: 128
        sourceSize.height: 128
        fillMode: Image.PreserveAspectFit

        mirror: root.facingRight
    }

    FrameAnimation {
        id: physicsLoop

        running: true
        onTriggered: tick(frameTime)
    }

    Timer {
        id: animTimer

        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (!root.dragging)
                root.frameIndex++;
        }
    }

    Timer {
        interval: 3000 + Math.random() * 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.dragging && root.onGround && root.walkTarget < 0 && root.currentAnim !== "ground") {
                if (Math.abs(root.vx) < 0.5) {
                    const roll = Math.random();
                    if (roll < 0.3) {
                        pickIdle();
                    } else if (roll < 0.55) {
                        walkRandom();
                    } else if (roll < 0.75) {
                        root.currentAnim = "dangle";
                        root.frameIndex = 0;
                    } else {
                        root.currentAnim = "layDown";
                        root.frameIndex = 0;
                    }
                }
            }
        }
    }
}
