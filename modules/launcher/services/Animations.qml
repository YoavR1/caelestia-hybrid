pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils // qmllint disable unused-imports

QtObject {
    id: root

    property var animations: []
    property bool initialized: false

    signal loaded

    property Process reader: Process {
        running: false
        command: ["sh", "-c", `ls -1 "${Paths.config}/animations"/*.lua 2>/dev/null || true`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let lines = text.trim().split("\n").filter(l => l.length > 0);
                    const result = [];

                    if (lines.length > 0) {
                        result.push({
                            name: "Default (None)",
                            path: "default"
                        });
                    }

                    for (let file of lines) {
                        let parts = file.split("/");
                        let filename = parts[parts.length - 1];
                        let name = filename.replace(/\.lua$/, "");
                        name = name.charAt(0).toUpperCase() + name.slice(1);
                        result.push({
                            name: name,
                            path: file
                        });
                    }

                    root.animations = result;
                    root.initialized = true;
                    root.loaded();
                } catch (e) {
                    console.error("Failed to parse animations: " + e);
                }
            }
        }
    }

    function loadAnimations() {
        if (initialized && animations.length > 0) {
            return;
        }
        animations = [];
        initialized = false;
        reader.running = true;
    }

    function reload() {
        animations = [];
        initialized = false;
        reader.running = true;
    }

    function applyAnimation(path, list) {
        if (list && list.screenState) {
            list.screenState.launcher = false;
        }

        let userConfig = `${Paths.config}/hypr-user.lua`;
        let script = `sed -i '/dofile(".*\\/animations\\/.*\\.lua")/d' "${userConfig}"\n`;
        script += `[ -s "${userConfig}" ] && [ -n "$(tail -c1 "${userConfig}")" ] && echo "" >> "${userConfig}"\n`;

        if (path !== "default") {
            script += `echo "dofile(\\"${path}\\")" >> "${userConfig}"\n`;
        }

        script += "hyprctl reload\n";
        Quickshell.execDetached(["sh", "-c", script]);
    }

    function query(searchText) {
        if (!searchText)
            return animations;

        const queryText = searchText.toLowerCase().trim();
        return animations.filter(a => a.name.toLowerCase().includes(queryText));
    }

    Component.onCompleted: loadAnimations()
}
