pragma Singleton

// Clipboard history, presented inside the shell.
//
// `cliphist` owns the store (a wl-paste watcher writes to it from the session
// autostart); this service only reads and replays entries, and only while the
// clipboard panel is open.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ id: "123", preview: "text", isImage: bool }]
    property var entries: []
    property bool loading: false

    function refresh() {
        if (listProc.running) return;
        root.loading = true;
        listProc.running = true;
    }

    function copy(entry) {
        // cliphist decode takes the numeric id on stdin and writes the original
        // bytes, which wl-copy then owns.
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\t' " + shellQuote(entry.id) + " | cliphist decode | wl-copy"]);
    }

    function remove(entry) {
        Quickshell.execDetached(["sh", "-c",
            "printf '%s\\t' " + shellQuote(entry.id) + " | cliphist delete"]);
        root.entries = root.entries.filter(e => e.id !== entry.id);
    }

    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.entries = [];
    }

    function shellQuote(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (line.trim() === "") continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    const id = line.slice(0, tab);
                    const preview = line.slice(tab + 1);
                    out.push({
                        id: id,
                        preview: preview,
                        isImage: /^\[\[\s*binary data/.test(preview)
                    });
                }
                root.entries = out;
                root.loading = false;
            }
        }
    }
}
