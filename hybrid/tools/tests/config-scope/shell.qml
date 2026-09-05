// Config scope semantics, which nothing else checks and which broke silently.
//
// The Nexus monitor selector passes "" for its "Global" scope, and every settings
// page writes through `GlobalConfig.forScreen(nState.targetScreen)`. If an empty
// name does not resolve to the root, every one of those writes lands on a layer
// nothing reads -- the value shows in the UI, an override marker appears, a file
// is written, and the setting does nothing. That was T62, and it applied to all
// 372 config keys at once, because it is a property of the resolver rather than
// of any key.
//
// Run through hybrid/tools/config-scope-test.sh, which isolates XDG_CONFIG_HOME
// so this never touches a real config, and reads the verdict from $RESULT_FILE
// rather than from stdout.

import QtQml
import Quickshell
import Quickshell.Io
import Caelestia.Config

ShellRoot {
    id: root

    property int failures: 0
    property var lines: []

    function check(name: string, ok: bool, detail: string): void {
        lines.push(`${ok ? "  ok  " : "  FAIL"} ${name}${ok || !detail ? "" : " -- " + detail}`);
        if (!ok)
            failures++;
    }

    function finish(): void {
        lines.push(failures === 0 ? "PASS config-scope: every invariant holds" : `FAIL config-scope: ${failures} invariant(s) broken`);
        resultFile.setText(lines.join("\n") + "\n");
    }

    Component.onCompleted: {
        const global = GlobalConfig.forScreen("");
        const screen = GlobalConfig.forScreen("TEST-SCREEN-1");

        // 1-3: resolver identity. These are synchronous properties of forScreen.
        check("forScreen('') is the root", global === GlobalConfig, `got ${global}`);
        check("forScreen(name) is a separate layer", screen !== GlobalConfig, "");
        check("forScreen(name) is stable across calls", screen === GlobalConfig.forScreen("TEST-SCREEN-1"), "");

        // 4-6: propagation. A layer syncs from its fallback through a notify, so the
        // result is not visible in the same tick as the write -- checking it
        // synchronously is a test bug, not a product one, and read as the latter once.
        const before = GlobalConfig.bar.position;
        const probe = before === "top" ? "bottom" : "top";
        global.bar.position = probe;

        Qt.callLater(() => {
            check("a Global write reaches a screen layer", screen.bar.position === probe, `wrote ${probe}, layer reads ${screen.bar.position}`);
            check("a Global write is visible on the root", GlobalConfig.bar.position === probe, `root reads ${GlobalConfig.bar.position}`);

            screen.bar.position = before;
            Qt.callLater(() => {
                check("a screen write does not leak to the root", GlobalConfig.bar.position === probe, `root reads ${GlobalConfig.bar.position}`);
                root.finish();
            });
        });
    }

    FileView {
        id: resultFile

        path: Quickshell.env("CONFIG_SCOPE_RESULT") || "/tmp/config-scope-result.txt"
        printErrors: true
    }
}
