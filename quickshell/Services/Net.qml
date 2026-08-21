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
    readonly property var wiredDevices: devices.filter(d => d.type === DeviceType.Wired)

    readonly property bool hasWifi: wifiDevices.length > 0
    readonly property bool hasWired: wiredDevices.length > 0

    readonly property var wifi: hasWifi ? wifiDevices[0] : null
    readonly property var wired: hasWired ? wiredDevices[0] : null

    // The device actually carrying traffic — prefer a connected wired link, then
    // connected wifi, then whatever exists.
    readonly property var primary: {
        for (const d of devices) if (d.type === DeviceType.Wired && d.connected) return d;
        for (const d of devices) if (d.type === DeviceType.Wifi && d.connected) return d;
        for (const d of devices) if (d.connected) return d;
        return devices.length > 0 ? devices[0] : null;
    }

    readonly property bool connected: primary !== null && primary.connected
    readonly property bool primaryIsWired: primary !== null && primary.type === DeviceType.Wired
    readonly property bool online: Networking.canCheckConnectivity
                                   ? Networking.connectivity === NetworkConnectivity.Full
                                   : connected

    readonly property string interfaceName: primary ? primary.name : "—"
    // NetworkDevice.address is the hardware (MAC) address; the useful thing to
    // show is the assigned IPv4, which is queried once per connectivity change
    // rather than polled.
    readonly property string macAddress: primary && primary.address ? primary.address : "—"

    // Interface name -> "10.0.0.5/24". One query covers every link, which is
    // what the per-link cards need; querying once per card would mean a process
    // spawn each, for the same output.
    property var addresses: ({})

    readonly property string ipv4: addressOf(primary)
    readonly property string wiredIpv4: addressOf(wired)
    readonly property string wifiIpv4: addressOf(wifi)

    function addressOf(dev) {
        if (!dev || !dev.name) return "—";
        const a = root.addresses[dev.name];
        return a ? a : "—";
    }

    onPrimaryChanged: ipQuery.restart()
    onConnectedChanged: ipQuery.restart()
    onWifiConnectedChanged: ipQuery.restart()
    onWiredConnectedChanged: ipQuery.restart()

    Timer {
        id: ipQuery
        interval: 400
        // No interface name is passed any more, so there is nothing here to
        // interpolate into a command; every link is read in one go and the
        // cards pick their own out of the map.
        onTriggered: ipProc.running = true
    }

    Process {
        id: ipProc
        command: ["ip", "-4", "-o", "addr", "show"]
        // One line per address, across all interfaces:
        //   2: ens18    inet 10.10.12.110/24 brd ... scope global ens18\  valid_lft ...
        // Field 2 is the interface, field 4 the address.
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    // Keep the first address per interface: a link with both a
                    // dynamic and a secondary address should read as the one it
                    // is actually reached on.
                    if (f.length >= 4 && f[2] === "inet" && !map[f[1]]) map[f[1]] = f[3];
                }
                root.addresses = map;
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
        if (primary.type === DeviceType.Wired)
            return primary.connected ? "Wired" : "Unplugged";
        return primary.connected ? primary.name : "Disconnected";
    }

    readonly property string typeLabel: {
        if (!primary) return "None";
        if (primary.type === DeviceType.Wifi) return "Wi-Fi";
        if (primary.type === DeviceType.Wired) return "Ethernet";
        return DeviceType.toString(primary.type);
    }

    // WifiNetwork.signalStrength is already 0..1 — it is declared `double` in
    // Quickshell's network.qmltypes, not a percentage. This used to divide by
    // 100 as well, which put every real signal under 0.01 and so pinned `icon`
    // to the weakest glyph for the entire life of a Wi-Fi connection, in the bar
    // as well as in the panels.
    readonly property real signalStrength: {
        if (!primary || primary.type !== DeviceType.Wifi || !primary.networks) return 0;
        for (const n of primary.networks.values)
            if (n.connected) return n.signalStrength;
        return 0;
    }

    // Bars and percentage for an arbitrary 0..1 strength. Exposed because the
    // connectivity tab needs them per network in its list, and the thresholds
    // should exist once rather than once per consumer.
    function glyphFor(strength) {
        const s = strength || 0;
        if (s > 0.75) return "󰤨";
        if (s > 0.5) return "󰤥";
        if (s > 0.25) return "󰤢";
        return "󰤟";
    }
    function percentFor(strength) { return Math.round((strength || 0) * 100); }

    readonly property string icon: {
        if (!connected) return "󰤭";
        // The same glyph the wired card uses, so the bar and the panel agree.
        if (primary.type === DeviceType.Wired) return "󰈀";
        return glyphFor(signalStrength);
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    function setWifiEnabled(on) { Networking.wifiEnabled = on; }

    // ── the wired link ──────────────────────────────────────────────────────
    // There is no "wired radio" to flip the way wifi has one, so the switch is
    // autoconnect plus an explicit disconnect. That keeps the device managed by
    // NetworkManager -- unmanaging it would work too, but it leaves the link
    // configured behind NM's back and is a worse thing to leave switched off.
    // Wifi facts that do not depend on wifi being the primary link: with a cable
    // in as well, the wifi card still has to describe itself.
    readonly property bool wifiConnected: wifi !== null && wifi.connected
    readonly property var wifiNetwork: {
        if (!wifi || !wifi.networks) return null;
        for (const n of wifi.networks.values) if (n.connected) return n;
        return null;
    }
    readonly property string wifiNetworkName: wifiNetwork ? wifiNetwork.name : ""
    readonly property real wifiSignal: wifiNetwork ? wifiNetwork.signalStrength : 0

    readonly property bool wiredEnabled: wired ? wired.autoconnect : false
    readonly property bool wiredHasLink: wired && wired.hasLink === true
    readonly property int wiredSpeed: wired && wired.linkSpeed ? wired.linkSpeed : 0
    readonly property bool wiredConnected: wired !== null && wired.connected

    function setWiredEnabled(on) {
        if (!wired) return;
        wired.autoconnect = on;
        // autoconnect alone only stops it coming back later; an active link has
        // to be told to go.
        if (!on && wired.connected) wired.disconnect();
    }


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

    // Wifi bitrate. Quickshell exposes linkSpeed on a wired device but has no
    // equivalent for wifi, so this comes from `iw`, which needs no privileges.
    // An argument vector rather than `sh -c` for the same reason as the address
    // query above: the interface name is interpolated and the kernel is not
    // careful about what it allows in one. Polled on the same subscription the
    // scanner uses, so it costs nothing while no list is on screen, and the
    // panels drop the figure entirely when iw is not installed.
    property int wifiSpeed: 0

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.scanSubscribers > 0 && root.wifi !== null && root.wifi.connected
        onTriggered: {
            wifiRateProc.command = ["iw", "dev", root.wifi.name, "link"];
            wifiRateProc.running = true;
        }
    }

    Process {
        id: wifiRateProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // "tx bitrate: 573.5 MBit/s HE-MCS 11 ..." — the rate is
                // renegotiated constantly, so this is the current rate rather
                // than anything the link is guaranteed to hold.
                const m = text.match(/tx bitrate:\s*([0-9.]+)/);
                root.wifiSpeed = m ? Math.round(parseFloat(m[1])) : 0;
            }
        }
        stderr: StdioCollector {}
    }

    // Scanning costs power and is only useful while a wifi list is on screen.
    property int scanSubscribers: 0
    function beginScan() { scanSubscribers++; }
    function endScan() { scanSubscribers = Math.max(0, scanSubscribers - 1); }
    onScanSubscribersChanged: if (wifi) wifi.scannerEnabled = scanSubscribers > 0
}
