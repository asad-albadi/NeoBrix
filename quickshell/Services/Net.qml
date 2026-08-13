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
            ipProc.command = ["sh", "-c",
                "ip -4 -o addr show dev " + root.primary.name
                + " 2>/dev/null | awk '{print $4}' | head -n1"];
            ipProc.running = true;
        }
    }

    Process {
        id: ipProc
        stdout: StdioCollector {
            onStreamFinished: root.ipv4 = text.trim() !== "" ? text.trim() : "—"
        }
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
