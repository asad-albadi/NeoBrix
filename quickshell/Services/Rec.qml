pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Screen recording state.
//
//  The recorder's own process is the state — there is nothing else to be the
//  source of truth, and a flag kept in here would be wrong the moment a
//  recording is stopped from a terminal or dies on its own. So this asks
//  `neobrix-record status`, which checks a live pid rather than a stale pidfile.
//
//  Polled only while something is watching, the same subscribe/unsubscribe
//  shape SysInfo uses: a shell that spawns a process every two seconds forever
//  to answer a question nobody asked is a shell that shows up in a battery
//  readout.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool recording: false

    property int subscribers: 0
    function subscribe() { subscribers++; probe.running = true; }
    function unsubscribe() { subscribers = Math.max(0, subscribers - 1); }

    function toggle() {
        Quickshell.execDetached(["neobrix-record", "toggle"]);
        // The script waits for the recorder to prove it started before it
        // reports anything, so give it longer than that before believing the
        // next probe.
        settle.restart();
    }

    Timer {
        interval: 2000
        running: root.subscribers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Timer {
        id: settle
        interval: 1200
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        command: ["neobrix-record", "status"]
        onExited: code => root.recording = (code === 0)
    }
}
