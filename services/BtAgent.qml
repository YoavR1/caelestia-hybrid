pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config

Singleton {
    id: root

    // --- Public properties for UI binding ---
    property bool active: false

    // Consecutive starts that never reached the socket. Reset once a connection succeeds, so
    // a long-running agent that crashes later is still retried from scratch.
    property int startFailures: 0
    property bool everConnected: false

    // Set once the agent has been given up on, so neither the process nor the socket is
    // retried again. Without it the socket kept reconnecting to a path nothing would ever
    // create, logging QLocalSocket::ServerNotFoundError on a loop.
    property bool gaveUp: false

    readonly property int maxStartFailures: 3
    property string requestType: ""    // "confirmation", "passkey", "pin", "display", "authorization"
    property string deviceName: ""
    property string devicePath: ""
    property string passkey: ""
    property int entered: 0

    // --- Public methods for UI actions ---
    function confirm(): void {
        sendMessage({
            "type": "confirm"
        });
        resetState();
    }

    function reject(): void {
        sendMessage({
            "type": "reject"
        });
        resetState();
    }

    function sendPasskey(value: string): void {
        sendMessage({
            "type": "passkey",
            "value": value
        });
        resetState();
    }

    function sendPin(value: string): void {
        sendMessage({
            "type": "pin",
            "value": value
        });
        resetState();
    }

    // --- Internal ---
    function resetState(): void {
        active = false;
        requestType = "";
        deviceName = "";
        devicePath = "";
        passkey = "";
        entered = 0;
    }

    function sendMessage(msg: var): void {
        if (sock.connected) {
            sock.write(JSON.stringify(msg) + "\n");
            sock.flush();
        }
    }

    function handleMessage(data: string): void {
        let msg;
        try {
            msg = JSON.parse(data);
        } catch (e) {
            console.warn("[BtAgent] Failed to parse message:", data);
            return;
        }

        switch (msg.type) {
        case "request_confirmation":
            root.devicePath = msg.device ?? "";
            root.deviceName = msg.name ?? "Unknown";
            root.passkey = msg.passkey ?? "";
            root.requestType = "confirmation";
            root.active = true;
            Toaster.toast(qsTr("Bluetooth pairing"), qsTr("Confirm pairing with %1").arg(root.deviceName), "bluetooth");
            break;
        case "request_passkey":
            root.devicePath = msg.device ?? "";
            root.deviceName = msg.name ?? "Unknown";
            root.requestType = "passkey";
            root.active = true;
            Toaster.toast(qsTr("Bluetooth pairing"), qsTr("Enter passkey for %1").arg(root.deviceName), "bluetooth");
            break;
        case "request_pin":
            root.devicePath = msg.device ?? "";
            root.deviceName = msg.name ?? "Unknown";
            root.requestType = "pin";
            root.active = true;
            Toaster.toast(qsTr("Bluetooth pairing"), qsTr("Enter PIN for %1").arg(root.deviceName), "bluetooth");
            break;
        case "request_authorization":
            root.devicePath = msg.device ?? "";
            root.deviceName = msg.name ?? "Unknown";
            root.requestType = "authorization";
            root.active = true;
            Toaster.toast(qsTr("Bluetooth pairing"), qsTr("%1 wants to pair").arg(root.deviceName), "bluetooth");
            break;
        case "display_passkey":
            root.devicePath = msg.device ?? "";
            root.deviceName = msg.name ?? "Unknown";
            root.passkey = msg.passkey ?? "";
            root.entered = msg.entered ?? 0;
            root.requestType = "display";
            root.active = true;
            break;
        case "cancel":
            root.resetState();
            break;
        default:
            console.warn("[BtAgent] Unknown message type:", msg.type);
        }
    }

    // --- Agent process lifecycle ---
    Process {
        id: agentProc

        command: ["python3", "-u", Quickshell.shellPath("scripts/bt-agent.py")]
        // Gated as well as lazily created. ServiceLoader only touches this singleton when
        // the flag is on, so with the feature off it should never exist -- but a stray
        // reference here does not merely poll something, it spawns a Python process that
        // registers a system-wide BlueZ pairing agent. That is worth a second gate.
        running: GlobalConfig.hybrid.features.btAgent

        stdout: SplitParser {
            onRead: data => console.log("[bt-agent/out]", data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("[bt-agent/err]", data)
        }

        onStarted: { // qmllint disable signal-handler-parameters
            console.log("[BtAgent] Agent process started");
            socketConnectTimer.start();
        }

        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            root.resetState();
            sock.connected = false;

            // Exit code 0 before ever connecting is not a failure: bt-agent.py exits cleanly
            // and deliberately when there is no D-Bus system bus to talk to, which is the
            // normal state of a container, a TTY session or a machine with Bluetooth removed.
            // It has decided it cannot run, and it will decide the same thing every three
            // seconds forever. Report it once, quietly, and stop -- restarting it is noise,
            // and warning about it says the shell is broken when it is merely idle.
            if (exitCode === 0 && !root.everConnected) {
                root.gaveUp = true;
                console.log("[BtAgent] Agent stopped without a D-Bus connection - Bluetooth pairing prompts are unavailable on this system. Not retrying.");
                return;
            }

            // Anything else that never reached the socket is a real start failure, and it will
            // recur for the same reason: a missing python-dbus or python-gobject exits with a
            // traceback immediately. Retrying that forever means a restart every three seconds
            // and a traceback in the log for as long as the shell runs. A crash *after* a
            // successful connection is different and is still retried indefinitely, because
            // that is a transient worth recovering from.
            if (root.everConnected) {
                root.startFailures = 0;
            } else if (++root.startFailures >= root.maxStartFailures) {
                root.gaveUp = true;
                console.warn("[BtAgent] Agent exited with code", exitCode, "without ever connecting,", root.startFailures, "times - giving up. Check that python-dbus and python-gobject are installed.");
                return;
            }

            console.warn("[BtAgent] Agent exited with code", exitCode, "- restarting in 3s");
            restartTimer.start();
        }
    }

    Timer {
        id: restartTimer

        interval: 3000
        // Re-check the flag rather than assigning `true`. This assignment breaks the binding
        // above -- that is unavoidable in an imperative restart -- so it has to carry the
        // gate itself, or a crash would resurrect the agent with the feature switched off.
        onTriggered: agentProc.running = !root.gaveUp && GlobalConfig.hybrid.features.btAgent
    }

    // Delay socket connection until agent has time to create the socket
    Timer {
        id: socketConnectTimer

        interval: 1000
        // Guarded like the reconnect timer. The agent can exit within this delay -- it does
        // exactly that where there is no D-Bus system bus -- and connecting afterwards asks
        // for a socket path nothing ever created, which quickshell reports as
        // QLocalSocket::ServerNotFoundError. That warning is the shell's, not ours, so the
        // only way to not emit it is to not make the call.
        onTriggered: sock.connected = !root.gaveUp && agentProc.running
    }

    // --- Socket connection to agent ---
    Socket {
        id: sock

        path: (Quickshell.env("XDG_RUNTIME_DIR") ?? ("/run/user/" + Quickshell.env("UID"))) + "/caelestia-bt-agent.sock"
        connected: false // Will be set to true by socketConnectTimer

        parser: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleMessage(data)
        }

        onConnectionStateChanged: {
            if (!connected) {
                if (root.gaveUp) {
                    // Nothing will ever answer on that path now, so reconnecting logs
                    // ServerNotFoundError every two seconds for the life of the shell.
                    return;
                }
                console.warn("[BtAgent] Socket disconnected, reconnecting in 2s");
                reconnectTimer.start();
            } else {
                // The agent is up and talking, so any earlier start failures were transient
                // and a later crash deserves the full retry budget again.
                root.everConnected = true;
                root.startFailures = 0;
                console.log("[BtAgent] Socket connected to agent");
            }
        }
    }

    Timer {
        id: reconnectTimer

        interval: 2000
        onTriggered: sock.connected = !root.gaveUp
    }
}
