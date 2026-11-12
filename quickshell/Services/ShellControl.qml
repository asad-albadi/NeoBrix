pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    readonly property bool ready: true

    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false); }
    }
}
