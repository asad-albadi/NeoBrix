pragma Singleton

// Display backlight, via brightnessctl.
//
// Only meaningful when Hw.hasBacklight; every consumer already gates on that, so
// on this VM (virtio-gpu, no backlight device) nothing here ever runs.

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {
    id: root

    property real value: 0        // 0..1

    readonly property string device: Hw.backlightDevice
    readonly property bool available: Hw.hasBacklight

    function set(v) {
        if (!available) return;
        const pct = Math.round(Math.max(1, Math.min(100, v * 100)));
        root.value = pct / 100;
        setProc.command = ["brightnessctl", "-d", root.device, "-q", "set", pct + "%"];
        setProc.running = true;
    }

    function step(d) { set(value + d); }

    Process { id: setProc }

    // brightnessctl does not notify, but sysfs does emit inotify on write, so a
    // watched FileView keeps us in sync with external changes (e.g. Fn keys).
    FileView {
        id: currentFile
        path: root.available ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        watchChanges: root.available
        printErrors: false
        onLoaded: {
            const raw = parseInt(text().trim());
            if (!isNaN(raw) && Hw.backlightMax > 0)
                root.value = raw / Hw.backlightMax;
        }
        onFileChanged: reload()
    }
}
