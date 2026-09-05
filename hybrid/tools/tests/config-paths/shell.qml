// Dump every reachable config property path from the live schema.
//
// The settings UI reaches keys by path -- `targetConfig.bar.position` -- and a path
// that does not exist writes nowhere and says nothing. Comparing what the pages
// reference against what the schema actually has needs the schema, and the schema
// is compiled C++, so the only honest source is the running plugin.
//
// Writes one path per line to $CONFIG_PATHS_OUT.

import QtQml
import Quickshell
import Quickshell.Io
import Caelestia.Config

ShellRoot {
    id: root

    Component.onCompleted: {
        const paths = [];
        const seen = new Set();

        // Depth-limited so a cycle or a self-referential node cannot hang the run.
        function walk(obj, prefix, depth) {
            if (!obj || depth > 6)
                return;
            for (const key in obj) {
                if (key.startsWith("_") || key === "objectName")
                    continue;
                const path = prefix ? `${prefix}.${key}` : key;
                if (seen.has(path))
                    continue;
                seen.add(path);

                let value;
                try {
                    value = obj[key];
                } catch (e) {
                    continue;
                }
                if (typeof value === "function")
                    continue;

                paths.push(path);

                // Recurse into config nodes only. A QObject with its own properties is a
                // subobject; a string, number, list or enum is a leaf.
                if (value && typeof value === "object" && !Array.isArray(value))
                    walk(value, path, depth + 1);
            }
        }

        walk(GlobalConfig, "", 0);
        paths.sort();
        out.setText(paths.join("\n") + "\n");
        console.log(`config-paths: ${paths.length} path(s)`);
    }

    FileView {
        id: out

        path: Quickshell.env("CONFIG_PATHS_OUT") || "/tmp/config-paths.txt"
        printErrors: true
    }
}
