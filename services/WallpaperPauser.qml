pragma Singleton

import QtQuick
import QtCore
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import qs.utils

Singleton {
    id: root

    property bool manualPause: false
    property bool pauseOnBattery: false
    property bool pauseOnWindowOverlap: true
    property string hwDecoder: "none"

    property bool paused: false

    property bool _loaded: false

    property string pauseReason: "None"

    function recalculate() {
        let newPaused = false;
        let reason = "None";

        // Rule #0 — Manual / Config Pause
        if (GlobalConfig.background.videoWallpaperPaused || manualPause) {
            newPaused = true;
            reason = "Manual / Config Pause";
        } else if (pauseOnBattery && UPower.onBattery) {
            newPaused = true;
            reason = "Battery";
        } else if (pauseOnWindowOverlap) {
            const monitor = Hyprland.focusedMonitor;
            const ws = monitor && monitor.activeWorkspace ? monitor.activeWorkspace : Hyprland.focusedWorkspace;

            if (ws) {
                // Strictly filter global toplevels to ONLY the focused workspace
                const toplevels = ws.toplevels.values;

                // Rule #3 — 2+ visible windows
                if (toplevels.length >= 2) {
                    newPaused = true;
                    reason = "2+ windows (" + toplevels.length + " total)";
                } else {
                    // Rule #2 — 70% of monitor area
                    if (monitor) {
                        const screen = Quickshell.screens.find(s => s.name === monitor.name);
                        if (screen) {
                            const screenArea = screen.width * screen.height;
                            if (screenArea > 0) {
                                const threshold = screenArea * 0.7;
                                for (const t of toplevels) {
                                    const size = t.lastIpcObject?.size;
                                    if (size && size.length >= 2 && size[0] * size[1] >= threshold) {
                                        newPaused = true;
                                        reason = "70% area rule by: " + (t.lastIpcObject?.title ?? "Unknown") + " (" + size[0] + "x" + size[1] + ")";
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        paused = newPaused;
        root.pauseReason = reason;
    }

    onManualPauseChanged: {
        recalculate();
    }

    onPauseOnBatteryChanged: {
        recalculate();
    }

    onPauseOnWindowOverlapChanged: {
        recalculate();
    }

    onHwDecoderChanged: {
        // We still need to sync this to a text file because the python CLI needs to read it
        // BEFORE the Qt application starts in order to inject the environment variables.
        if (root._loaded) {
            saveHwDecoderProcess.command = ["sh", "-c", "echo '" + root.hwDecoder + "' > ~/.cache/caelestia/hwDecoder.txt && nohup sh -c 'sleep 0.5 && caelestia shell -d' >/dev/null 2>&1 & caelestia shell -k"];
            saveHwDecoderProcess.running = true;
        }
    }

    Component.onCompleted: {
        root._loaded = true;
        recalculate();
    }

    Settings {
        id: pauserSettings

        property alias manualPause: root.manualPause

        property alias pauseOnBattery: root.pauseOnBattery

        property alias pauseOnWindowOverlap: root.pauseOnWindowOverlap

        property alias hwDecoder: root.hwDecoder

        location: `${Paths.state}/wallpaper/pauser.ini`
        category: "WallpaperPauser"
    }

    Process {
        id: saveHwDecoderProcess
    }

    Connections {
        function onFocusedWorkspaceChanged() {
            root.recalculate();
        }

        function onFocusedMonitorChanged() {
            root.recalculate();
        }

        function onRawEvent(event) {
            const n = event.name;
            if (n.startsWith("workspace") || n.startsWith("activewindow") || n.startsWith("createworkspace") || n.startsWith("destroyworkspace") || ["fullscreen", "changefloatingmode", "minimize", "movewindow", "openwindow", "closewindow", "moveworkspace", "focusedmon"].includes(n)) {
                recalcTimer.restart();
            }
        }

        target: Hyprland
    }

    Connections {
        function onOnBatteryChanged() {
            recalcTimer.restart();
        }

        target: UPower
    }

    Timer {
        id: recalcTimer

        interval: 50
        onTriggered: root.recalculate()
    }

    // Startup timer to ensure we catch the asynchronously loaded Hyprland and Quickshell state
    Timer {
        id: startupTimer

        property int attempts: 0

        interval: 1000
        repeat: true
        running: true

        onTriggered: {
            root.recalculate();
            attempts++;
            if (attempts >= 5) {
                running = false;
            }
        }
    }
}
