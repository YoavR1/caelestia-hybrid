pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services

Singleton {
    id: root

    // --- State Properties ---
    property bool active: false

    property bool pending: false
    property string statusText: active ? qsTr("Broadcasting") : qsTr("Disabled")

    // --- Hotspot Configuration ---
    property string ssid: "Caelestia-Hotspot"

    // Deliberately empty. `nmcli device wifi hotspot` generates a password when none is
    // given (see nmcli(1): "If not provided, nmcli will generate a password"), so every
    // install gets its own WPA PSK. OP shipped the constant "caelestia1234" here, which
    // replaced that per-install secret with one published in this repository: anyone in
    // radio range who has read the source is on the network. The generated key is read
    // back by `readConfigProc` after a successful start and shown in the settings field.
    property string password: ""
    property string band: "bg" // "bg" (2.4 GHz) | "a" (5 GHz)
    property string iface: ""

    // --- Connected Devices ---
    property var connectedClients: []

    readonly property int clientCount: connectedClients.length

    property string lastError: ""

    // --- Public Methods ---
    function toggle(): void {
        if (active) {
            stop();
        } else {
            start();
        }
    }

    function start(): void {
        if (pending || startProc.running)
            return;

        pending = true;
        detectInterface();

        const args = ["device", "wifi", "hotspot"];
        if (iface.length > 0) {
            args.push("ifname", iface);
        }
        if (ssid.length > 0) {
            args.push("ssid", ssid);
        }
        if (password.length >= 8) {
            args.push("password", password);
        }
        if (band === "bg" || band === "a") {
            args.push("band", band);
        }

        startProc.command = ["nmcli", ...args];
        startProc.running = true;
    }

    function stop(): void {
        if (pending || stopProc.running)
            return;

        pending = true;
        stopProc.command = ["nmcli", "connection", "down", "Hotspot"];
        stopProc.running = true;
    }

    function detectInterface(): void {
        if (iface.length === 0) {
            detectProc.running = true;
        }
    }

    function refreshStatus(): void {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function refreshClients(): void {
        if (iface.length > 0 && !clientsProc.running) {
            clientsProc.running = true;
        }
    }

    function readSavedConfig(): void {
        if (!readConfigProc.running) {
            readConfigProc.running = true;
        }
    }

    function updateCredentials(newSsid: string, newPass: string, newBand: string): void {
        if (newSsid.length > 0)
            ssid = newSsid;
        if (newPass.length >= 8)
            password = newPass;
        if (newBand === "bg" || newBand === "a")
            band = newBand;

        // If hotspot is currently active, restart it with new credentials
        if (active) {
            stop();
            restartTimer.restart();
        }
    }

    onActiveChanged: {
        Nmcli.refreshStatus(() => {});
        Nmcli.getNetworks(() => {});
    }

    Component.onCompleted: {
        root.detectInterface();
        root.readSavedConfig();
        root.refreshStatus();
    }

    // --- Lifecycle Timers ---
    Timer {
        id: pollTimer

        interval: root.active ? 4000 : 10000
        repeat: true
        // Gated on the feature flag as well as instantiated lazily. Reaching this singleton
        // at all should be impossible with the feature off -- nothing references it but the
        // Nexus page, whose entry point is hidden -- but this timer runs `nmcli` forever at
        // 10s once it starts, so a stray reference must not silently cost a process every
        // ten seconds for a feature the user has switched off.
        running: GlobalConfig.hybrid.features.hotspot
        onTriggered: {
            root.refreshStatus();
            if (root.active) {
                root.refreshClients();
            }
        }
    }

    Timer {
        id: restartTimer

        interval: 1200
        repeat: false
        onTriggered: root.start()
    }

    // --- Background Process Runners ---
    // 1. Start Hotspot Process
    Process {
        id: startProc

        command: ["nmcli", "device", "wifi", "hotspot"]

        // stdout is deliberately not captured. `nmcli device wifi hotspot` prints the
        // hotspot password there -- that is the documented way to learn a generated one --
        // so echoing it to the shell log wrote the WPA PSK into the journal in plaintext.
        // The password reaches the user through the settings field, via `readConfigProc`.

        stderr: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (line.length > 0) {
                    root.lastError = line;
                    console.warn("[Hotspot stderr]", line);
                }
            }
        }

        onExited: (code, status) => { // qmllint disable signal-handler-parameters
            root.pending = false;
            root.refreshStatus();
            if (code === 0) {
                root.active = true;
                root.lastError = "";
                // nmcli may have generated the password; re-read so the settings field can
                // show the user what it actually is.
                root.readSavedConfig();
                Toaster.toast(qsTr("Wi-Fi Hotspot"), qsTr("Hotspot '%1' is now active").arg(root.ssid), "wifi_tethering");
                root.refreshClients();
            } else {
                let msg = qsTr("Failed to start Hotspot.");
                if (root.lastError.includes("IP configuration") || root.lastError.includes("reserved")) {
                    msg = qsTr("Missing 'dnsmasq' package for DHCP. Install with: sudo pacman -S dnsmasq");
                } else if (root.lastError.includes("supplicant") || root.lastError.includes("authenticate")) {
                    if (root.band === "a") {
                        msg = qsTr("5 GHz not supported in AP mode by card/regdomain. Falling back to 2.4 GHz...");
                        root.band = "bg";
                        restartTimer.restart();
                    } else {
                        msg = qsTr("Wi-Fi device busy or supplicant timed out. Try toggling Wi-Fi off and on.");
                    }
                } else if (root.lastError.length > 0) {
                    msg = root.lastError;
                }
                Toaster.toast(qsTr("Wi-Fi Hotspot Error"), msg, "error");
            }
        }
    }

    // 2. Stop Hotspot Process
    Process {
        id: stopProc

        command: ["nmcli", "connection", "down", "Hotspot"]

        onExited: (code, status) => { // qmllint disable signal-handler-parameters
            root.pending = false;
            root.active = false;
            root.connectedClients = [];
            Toaster.toast(qsTr("Wi-Fi Hotspot"), qsTr("Hotspot turned off"), "wifi_tethering_off");
            root.refreshStatus();
        }
    }

    // 3. Detect Wireless Interface
    Process {
        id: detectProc

        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device", "status"]

        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split("\n");
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length >= 2 && parts[1] === "wifi") {
                        root.iface = parts[0];
                        break;
                    }
                }
            }
        }
    }

    // 4. Status Check Process
    Process {
        id: statusProc

        command: ["nmcli", "-t", "-f", "TYPE,NAME,DEVICE", "connection", "show", "--active"]

        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split("\n");
                let isHotspotActive = false;
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length >= 2 && parts[0] === "802-11-wireless" && (parts[1] === "Hotspot" || parts[1].toLowerCase().includes("hotspot"))) {
                        isHotspotActive = true;
                        if (parts.length >= 3 && parts[2].length > 0) {
                            root.iface = parts[2];
                        }
                        break;
                    }
                }
                if (root.active !== isHotspotActive && !root.pending) {
                    root.active = isHotspotActive;
                }
            }
        }
    }

    // 5. Read Saved Hotspot Config
    Process {
        id: readConfigProc

        command: ["nmcli", "-s", "-t", "-f", "802-11-wireless.ssid,802-11-wireless-security.psk,802-11-wireless.band", "connection", "show", "Hotspot"]

        stdout: SplitParser {
            onRead: data => {
                const lines = data.trim().split("\n");
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length >= 2) {
                        const key = parts[0];
                        const val = parts.slice(1).join(":");
                        if (key === "802-11-wireless.ssid" && val.length > 0) {
                            root.ssid = val;
                        } else if (key === "802-11-wireless-security.psk" && val.length > 0) {
                            root.password = val;
                        } else if (key === "802-11-wireless.band" && val.length > 0) {
                            root.band = val;
                        }
                    }
                }
            }
        }
    }

    // 6. Connected Clients Process (ip -j neigh)
    Process {
        id: clientsProc

        command: ["ip", "-j", "neigh", "show", "dev", root.iface ? root.iface : "wlo1"]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) {
                        const clients = [];
                        for (const item of parsed) {
                            if (item.dst && item.lladdr && item.state && !item.state.includes("FAILED")) {
                                clients.push({
                                    ip: item.dst,
                                    mac: item.lladdr,
                                    state: item.state.join(", ")
                                });
                            }
                        }
                        root.connectedClients = clients;
                    }
                } catch (e) {
                    // Ignore JSON parsing errors on empty or non-JSON output
                }
            }
        }
    }
}
