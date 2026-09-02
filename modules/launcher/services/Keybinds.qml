pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

QtObject {
    id: root

    property var keybinds: []
    property bool initialized: false

    signal loaded

    property Process luaReader: Process {
        running: false
        command: ["lua", Quickshell.shellDir + "/assets/scripts/parse_keybinds.lua"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    if (Array.isArray(parsed)) {
                        root.keybinds = parsed;
                        root.initialized = true;
                        root.loaded();
                        return;
                    }
                } catch (e) {
                    console.error("Failed to parse lua keybinds: " + e);
                }
                // If Lua parsing failed or returned invalid data, try fallback
                if (!root.initialized && !root.fallbackReader.running) {
                    root.fallbackReader.running = true;
                }
            }
        }
    }

    property Process fallbackReader: Process {
        running: false
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const binds = JSON.parse(text);
                    const formattedBinds = [];

                    for (const b of binds) {
                        const action = b.dispatcher + (b.arg ? " " + b.arg : "");
                        const description = (b.has_description !== undefined && b.has_description && b.description) ? b.description : action;
                        
                        let mods = [];
                        const m = b.modmask;
                        if (m & 64) mods.push("Super");
                        if (m & 8) mods.push("Alt");
                        if (m & 4) mods.push("Ctrl");
                        if (m & 1) mods.push("Shift");
                        
                        let keyText = b.key;
                        if (keyText === "") {
                            if (b.catch_all) {
                                keyText = "Catchall";
                            } else {
                                continue;
                            }
                        }

                        let bindText = mods.join(" + ");
                        if (bindText !== "") bindText += " + ";
                        bindText += keyText;

                        formattedBinds.push({
                            bind: bindText,
                            action: action,
                            description: description
                        });
                    }
                    
                    root.keybinds = formattedBinds;
                    root.initialized = true;
                    root.loaded();
                } catch (e) {
                    console.error("Failed to parse hyprctl binds -j: " + e);
                }
            }
        }
    }

    function loadKeybinds() {
        if (initialized && keybinds.length > 0) {
            return;
        }
        keybinds = [];
        initialized = false;
        if (Hypr.usingLua) {
            luaReader.running = true;
        } else {
            fallbackReader.running = true;
        }
    }

    function reload() {
        keybinds = [];
        initialized = false;
        if (Hypr.usingLua) {
            luaReader.running = true;
        } else {
            fallbackReader.running = true;
        }
    }

    function query(searchText) {
        if (!searchText)
            return keybinds;

        const queryText = searchText.toLowerCase().trim();
        return keybinds.filter(k => 
            (k.bind && k.bind.toLowerCase().includes(queryText)) ||
            (k.description && k.description.toLowerCase().includes(queryText)) ||
            (k.action && k.action.toLowerCase().includes(queryText))
        );
    }

    function execute(item) {
        if (!item)
            return;

        // 1. Direct shell command execution (apps, scripts, cli commands)
        if (item.cmd) {
            Quickshell.execDetached(["sh", "-c", item.cmd]);
            return;
        }

        // 2. Direct Lua evaluation in Hyprland
        if (Hypr.usingLua && item.lua) {
            Quickshell.execDetached(["hyprctl", "eval", item.lua]);
            return;
        }

        // 3. Fallback handlers for raw action string
        const action = (item.action || "").trim();
        if (!action)
            return;

        if (action.startsWith("exec ")) {
            Quickshell.execDetached(["sh", "-c", action.slice(5)]);
        } else if (action.startsWith("global ")) {
            const name = action.slice(7).trim();
            if (Hypr.usingLua) {
                Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.global("${name}")`]);
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", action]);
            }
        } else if (action.startsWith("eval ")) {
            Quickshell.execDetached(["hyprctl", "eval", action.slice(5)]);
        } else {
            if (Hypr.usingLua) {
                Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.${action}()`]);
            } else {
                Quickshell.execDetached(["hyprctl", "dispatch", action]);
            }
        }
    }

    Component.onCompleted: {
        loadKeybinds();
        Hypr.configReloaded.connect(root.reload);
    }
}