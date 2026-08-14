pragma Singleton

// ─────────────────────────────────────────────────────────────────────────────
//  Networking — native NetworkManager binding via Quickshell.Networking.
//  No `nmcli` polling anywhere.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    readonly property var wifiDevices: devices.filter(d => d.type === DeviceType.Wifi)
    readonly property var wiredDevices: devices.filter(d => d.type === DeviceType.Ethernet)

    readonly property bool hasWifi: wifiDevices.length > 0
    readonly property bool hasWired: wiredDevices.length > 0

    readonly property var wifi: hasWifi ? wifiDevices[0] : null
    readonly property var wired: hasWired ? wiredDevices[0] : null

    // The device actually carrying traffic — prefer a connected wired link, then
    // connected wifi, then whatever exists.
    readonly property var primary: {
        for (const d of devices) if (d.type === DeviceType.Ethernet && d.connected) return d;
        for (const d of devices) if (d.type === DeviceType.Wifi && d.connected) return d;
        for (const d of devices) if (d.connected) return d;
        return devices.length > 0 ? devices[0] : null;
    }

    readonly property bool connected: primary !== null && primary.connected
    readonly property bool online: Networking.canCheckConnectivity
                                   ? Networking.connectivity === NetworkConnectivity.Full
                                   : connected

    readonly property string interfaceName: primary ? primary.name : "—"
    // NetworkDevice.address is the hardware (MAC) address; the useful thing to
    // show is the assigned IPv4, which is queried once per connectivity change
    // rather than polled.
    readonly property string macAddress: primary && primary.address ? primary.address : "—"
    property string ipv4: "—"

    onPrimaryChanged: ipQuery.restart()
    onConnectedChanged: ipQuery.restart()

    Timer {
        id: ipQuery
        interval: 400
        onTriggered: {
            if (!root.primary) { root.ipv4 = "—"; return; }
            // Argument vector, not `sh -c`: the interface name is interpolated
            // here, and the kernel permits ';', '$()' and '|' in an ifname (it
            // rejects only whitespace, '/' and ':'). Naming an interface needs
            // CAP_NET_ADMIN so this was never reachable, but there is no reason
            // to hand an externally-derived string to a shell for a command that
            // does not need one.
            ipProc.command = ["ip", "-4", "-o", "addr", "show", "dev", root.primary.name];
            ipProc.running = true;
        }
    }

    Process {
        id: ipProc
        // `ip -4 -o addr show dev X` prints one line per address:
        //   2: ens18    inet 10.10.12.110/24 brd ... scope global ens18\  valid_lft ...
        // The address is the fourth whitespace-separated field of the first line,
        // which is what the old awk/head pipeline extracted.
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n").find(l => l.trim() !== "");
                const fields = line ? line.trim().split(/\s+/) : [];
                root.ipv4 = fields.length >= 4 ? fields[3] : "—";
            }
        }
        // Swallowed rather than logged: querying an interface that disappeared
        // between the signal and the timer is routine, not an error worth noise.
        stderr: StdioCollector {}
    }

    // Name of the active connection: SSID on wifi, connection profile on wired.
    readonly property string connectionName: {
        if (!primary) return "Disconnected";
        if (primary.type === DeviceType.Wifi) {
            if (primary.networks)
                for (const n of primary.networks.values)
                    if (n.connected) return n.name;
            return primary.connected ? "Wi-Fi" : "Disconnected";
        }
        if (primary.type === DeviceType.Ethernet)
            return primary.connected ? "Wired" : "Unplugged";
        return primary.connected ? primary.name : "Disconnected";
    }

    readonly property string typeLabel: {
        if (!primary) return "None";
        if (primary.type === DeviceType.Wifi) return "Wi-Fi";
        if (primary.type === DeviceType.Ethernet) return "Ethernet";
        return DeviceType.toString(primary.type);
    }

    readonly property real signalStrength: {
        if (!primary || primary.type !== DeviceType.Wifi || !primary.networks) return 0;
        for (const n of primary.networks.values)
            if (n.connected) return n.signalStrength / 100;
        return 0;
    }

    readonly property string icon: {
        if (!connected) return "󰤭";
        if (primary.type === DeviceType.Ethernet) return "󰈁";
        const s = signalStrength;
        if (s > 0.75) return "󰤨";
        if (s > 0.5) return "󰤥";
        if (s > 0.25) return "󰤢";
        return "󰤟";
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    function setWifiEnabled(on) { Networking.wifiEnabled = on; }

    readonly property var visibleNetworks: {
        if (!wifi || !wifi.networks) return [];
        const seen = {};
        const out = [];
        for (const n of wifi.networks.values) {
            if (!n.name || seen[n.name]) continue;
            seen[n.name] = true;
            out.push(n);
        }
        out.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
                        || (b.signalStrength || 0) - (a.signalStrength || 0));
        return out;
    }

    // Scanning costs power and is only useful while a wifi list is on screen.
    property int scanSubscribers: 0
    function beginScan() { scanSubscribers++; }
    function endScan() { scanSubscribers = Math.max(0, scanSubscribers - 1); }
    onScanSubscribersChanged: if (wifi) wifi.scannerEnabled = scanSubscribers > 0
}
