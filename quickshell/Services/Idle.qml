pragma Singleton

// Keep awake.
//
// The lock itself is a logind inhibitor held by a detached process, which is the
// mechanism hypridle already respects -- hypridle.conf sets
// ignore_systemd_inhibit = false, so while the lock is held nothing dims, locks,
// blanks or suspends. neobrix-idle owns it; this only asks.
//
// Deliberately not polled. The state changes when somebody presses the button,
// so it is read then, at startup, and whenever a panel that displays it opens.
// A lock taken from a terminal shows up at the next of those, which is soon
// enough for something the machine itself never changes on its own.

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool inhibited: state === "on"
    property string state: "off"

    // True while a toggle is in flight, so the row does not invite a second
    // press before the first has taken.
    property bool busy: false

    function refresh() { statusProc.running = true; }

    function toggle() {
        if (root.busy) return;
        root.busy = true;
        toggleProc.running = true;
    }

    Process {
        id: statusProc
        command: ["neobrix-idle", "inhibit", "status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (s === "on" || s === "off") root.state = s;
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: toggleProc
        command: ["neobrix-idle", "inhibit", "toggle"]
        running: false
        onExited: { root.busy = false; root.refresh(); }
        stderr: StdioCollector {}
    }
}
