pragma Singleton

// Bluetooth — native BlueZ binding. Every consumer checks `available` first, so
// on a machine with no adapter (this VM) the whole section disappears instead of
// rendering a dead toggle.

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering

    readonly property var devices: {
        if (!available || !adapter.devices) return [];
        const out = [];
        for (const d of adapter.devices.values)
            if (d.paired || d.connected || d.bonded) out.push(d);
        out.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));
        return out;
    }

    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property int connectedCount: connectedDevices.length

    readonly property string icon: !available ? "󰂲"
                                 : !enabled ? "󰂲"
                                 : connectedCount > 0 ? "󰂱" : "󰂯"

    readonly property string statusText: !available ? "No adapter"
                                       : !enabled ? "Off"
                                       : connectedCount > 0
                                         ? connectedDevices[0].deviceName + (connectedCount > 1
                                             ? " +" + (connectedCount - 1) : "")
                                         : "On"

    function setEnabled(on) { if (available) adapter.enabled = on; }
    function toggle() { setEnabled(!enabled); }
    function setDiscovering(on) { if (available) adapter.discovering = on; }
}
