// Connectivity tab — the wired link, Wi-Fi and Bluetooth.
//
// This was a card in the SYSTEM tab's 250px right-hand column, which worked only
// because the VM Neobrix was built on has neither a wireless card nor a
// Bluetooth adapter: with both present the Bluetooth block ran off the bottom of
// the card. It is a tab of its own now, and the lists have room to scroll rather
// than clip.
//
// Hardware gating is unchanged and still comes from the services: the Wi-Fi half
// exists only when Net.hasWifi, the Bluetooth half only when BlueZ reports an
// adapter. With neither, the tab is the wired summary plus an explicit note —
// never an empty shell or a toggle that does nothing.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    // Set by ControlCenter to (panel open && this tab selected).
    property bool active: false

    // Scanning costs power, so it runs only while this tab is actually on
    // screen. beginScan/endScan are reference-counted in Net, so the two calls
    // have to stay paired — hence the destruction guard.
    readonly property bool scanning: root.active && Net.hasWifi && Net.wifiEnabled
    onScanningChanged: scanning ? Net.beginScan() : Net.endScan()
    Component.onDestruction: if (scanning) Net.endScan()

    // ── security helpers ────────────────────────────────────────────────────
    // Owe is opportunistic ("enhanced open") encryption with no passphrase, so
    // it counts as open for the purpose of "can I join this by clicking it".
    function secured(sec) {
        return sec !== WifiSecurityType.Open
            && sec !== WifiSecurityType.Owe
            && sec !== WifiSecurityType.Unknown;
    }

    function secLabel(sec) {
        switch (sec) {
        case WifiSecurityType.Open:          return "OPEN";
        case WifiSecurityType.Owe:           return "OWE";
        case WifiSecurityType.Sae:
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3";
        case WifiSecurityType.Wpa2Psk:
        case WifiSecurityType.Wpa2Eap:       return "WPA2";
        case WifiSecurityType.WpaPsk:
        case WifiSecurityType.WpaEap:        return "WPA";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:    return "WEP";
        case WifiSecurityType.Leap:          return "LEAP";
        }
        return "";
    }

    // Bars and percentages come from Net.glyphFor/Net.percentFor, so the 0..1
    // thresholds live in the service and not a second time here.
    //
    // The joined network is still looked up locally, but only for its security
    // type: the service exposes strength and name for the primary connection,
    // not which cipher it negotiated.
    readonly property var activeNetwork: {
        for (const n of Net.visibleNetworks) if (n.connected) return n;
        return null;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceMd

        // ── active link ─────────────────────────────────────────────────────
        BrixCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: Theme.radiusMd
            color: Theme.surface
            shadowOffset: Theme.shadowSm

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spaceSm
                spacing: Theme.spaceSm

                BrixCard {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: Theme.radiusSm
                    shadowOffset: Theme.shadowSm
                    color: Net.connected ? Theme.secondary : Theme.error

                    Text {
                        anchors.centerIn: parent
                        text: Net.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXl
                        color: Theme.textOn(parent.color)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: Net.connectionName
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLg
                        font.weight: Theme.weightHeavy
                        color: Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Net.typeLabel + " · " + Net.interfaceName
                              + (Net.ipv4 !== "—" ? " · " + Net.ipv4 : "")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        font.weight: Theme.weightBold
                        color: Theme.foregroundDim
                    }
                    // Deliberately not the MAC address: it identifies the
                    // machine and these panels end up in screenshots.
                    Text {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: {
                            if (root.activeNetwork)
                                return root.secLabel(root.activeNetwork.security)
                                     + " · " + Net.percentFor(Net.signalStrength) + "% signal";
                            if (Net.hasWired && Net.wired.hasLink && Net.wired.linkSpeed > 0)
                                return "LINK " + Net.wired.linkSpeed + " Mb/s";
                            return "";
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.foregroundDim
                    }
                }

                BrixChip {
                    text: Net.online ? "FULL" : (Net.connected ? "LIMITED" : "DOWN")
                    accent: Net.online ? Theme.secondary
                          : Net.connected ? Theme.warning : Theme.error
                }
            }
        }

        // ── the two radios, side by side ────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            // ── Wi-Fi ───────────────────────────────────────────────────────
            BrixCard {
                visible: Net.hasWifi
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

                        SectionHeader { text: "WI-FI"; icon: "󰤨"; Layout.fillWidth: true }

                        BrixToggle {
                            checked: Net.wifiEnabled
                            onToggled: on => Net.setWifiEnabled(on)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: !Net.wifiEnabled ? "Radio off"
                            : Net.visibleNetworks.length === 0 ? "Scanning…"
                            : Net.visibleNetworks.length + " network"
                              + (Net.visibleNetworks.length === 1 ? "" : "s") + " in range"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.foregroundDim
                    }

                    // The list is inset well inside the card, so a rectangular
                    // clip never meets the card's rounded corners and no
                    // ClippingRectangle is needed.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Net.wifiEnabled
                        spacing: Theme.spaceXs

                        ListView {
                            id: wifiList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: Net.visibleNetworks
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: netRow
                                required property var modelData

                                // Joining a secured network with no saved
                                // profile needs a passphrase, and there is no
                                // field for one yet — so the row says what to do
                                // instead of offering a click that fails
                                // silently. Not a protocol limitation:
                                // WifiNetwork.connectWithPsk(psk) exists and is
                                // the supported path once there is a prompt to
                                // feed it.
                                readonly property bool joinable:
                                    netRow.modelData.known || !root.secured(netRow.modelData.security)

                                width: ListView.view.width
                                height: 34

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusXs
                                    color: netRow.modelData.connected ? Theme.secondary
                                         : netMouse.containsMouse ? Theme.surfaceDeep : "transparent"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceXs
                                    anchors.rightMargin: Theme.spaceXs
                                    spacing: Theme.spaceXs

                                    Text {
                                        text: Net.glyphFor(netRow.modelData.signalStrength)
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontMd
                                        color: netRow.modelData.connected
                                               ? Theme.textOn(Theme.secondary) : Theme.foreground
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -2

                                        Text {
                                            Layout.fillWidth: true
                                            text: netRow.modelData.name
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSm
                                            font.weight: Theme.weightBold
                                            color: netRow.modelData.connected
                                                   ? Theme.textOn(Theme.secondary) : Theme.foreground
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                const parts = [];
                                                const sec = root.secLabel(netRow.modelData.security);
                                                if (sec !== "") parts.push(sec);
                                                parts.push(Net.percentFor(netRow.modelData.signalStrength) + "%");
                                                if (!netRow.joinable) parts.push("needs nmtui once");
                                                return parts.join(" · ");
                                            }
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            color: netRow.modelData.connected
                                                   ? Theme.textOn(Theme.secondary) : Theme.foregroundDim
                                        }
                                    }

                                    Text {
                                        visible: root.secured(netRow.modelData.security)
                                        text: "󰌾"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSm
                                        color: netRow.modelData.connected
                                               ? Theme.textOn(Theme.secondary) : Theme.foregroundDim
                                    }

                                    BrixChip {
                                        visible: netRow.modelData.known && !netRow.modelData.connected
                                        text: "SAVED"
                                        fontSize: 8
                                        accent: Theme.surfaceDeep
                                    }

                                    BrixChip {
                                        visible: netRow.modelData.connected || netRow.modelData.stateChanging
                                        text: netRow.modelData.stateChanging ? "JOINING" : "CONNECTED"
                                        fontSize: 8
                                        accent: Theme.surface
                                    }
                                }

                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: netRow.joinable || netRow.modelData.connected
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (netRow.modelData.connected) netRow.modelData.disconnect();
                                        else netRow.modelData.connect();
                                    }
                                }
                            }
                        }

                        ScrollTrack { list: wifiList; Layout.fillHeight: true }
                    }

                    Placeholder {
                        visible: !Net.wifiEnabled
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        glyph: "󰤮"
                        label: "radio off"
                    }
                }
            }

            // ── Bluetooth ───────────────────────────────────────────────────
            BrixCard {
                visible: Bt.available
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spaceSm

                        SectionHeader { text: "BLUETOOTH"; icon: Bt.icon; Layout.fillWidth: true }

                        BrixToggle {
                            checked: Bt.enabled
                            accent: Theme.info
                            onToggled: on => Bt.setEnabled(on)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: Bt.statusText + (Bt.discovering ? " · discovering" : "")
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.foregroundDim
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Bt.enabled && Bt.devices.length > 0
                        spacing: Theme.spaceXs

                        ListView {
                            id: btList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: Bt.enabled ? Bt.devices : []
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: btRow
                                required property var modelData
                                width: ListView.view.width
                                height: 34

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusXs
                                    color: btRow.modelData.connected ? Theme.info : "transparent"
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceXs
                                    anchors.rightMargin: Theme.spaceXs
                                    spacing: Theme.spaceXs

                                    Text {
                                        text: btRow.modelData.connected ? "󰂱" : "󰂯"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontMd
                                        color: btRow.modelData.connected
                                               ? Theme.textOn(Theme.info) : Theme.foreground
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: -2

                                        Text {
                                            Layout.fillWidth: true
                                            text: btRow.modelData.deviceName
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSm
                                            font.weight: Theme.weightBold
                                            color: btRow.modelData.connected
                                                   ? Theme.textOn(Theme.info) : Theme.foreground
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: {
                                                const parts = [];
                                                if (btRow.modelData.pairing) parts.push("pairing");
                                                else if (btRow.modelData.connected) parts.push("connected");
                                                else if (btRow.modelData.paired || btRow.modelData.bonded) parts.push("paired");
                                                if (btRow.modelData.batteryAvailable)
                                                    parts.push(Math.round(btRow.modelData.battery * 100) + "%");
                                                return parts.join(" · ");
                                            }
                                            elide: Text.ElideRight
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 8
                                            color: btRow.modelData.connected
                                                   ? Theme.textOn(Theme.info) : Theme.foregroundDim
                                        }
                                    }

                                    BrixButton {
                                        text: btRow.modelData.connected ? "Disconnect" : "Connect"
                                        fontSize: 8
                                        vPadding: 2
                                        accent: btRow.modelData.connected ? Theme.surface : Theme.surfaceAlt
                                        onClicked: {
                                            if (btRow.modelData.connected) btRow.modelData.disconnect();
                                            else btRow.modelData.connect();
                                        }
                                    }
                                }
                            }
                        }

                        ScrollTrack { list: btList; Layout.fillHeight: true }
                    }

                    // Paired devices are what this list shows; pairing itself is
                    // not in the shell, so say where it happens rather than
                    // leaving an empty box.
                    Placeholder {
                        visible: !Bt.enabled || Bt.devices.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        glyph: Bt.enabled ? "󰂯" : "󰂲"
                        label: Bt.enabled ? "no paired devices" : "adapter off"
                        hint: Bt.enabled ? "pair once with bluetoothctl" : ""
                    }
                }
            }

            // ── neither radio ───────────────────────────────────────────────
            // Keeps the tab honest on hardware like the VM this was built on:
            // the wired summary above is the whole story, and this says so
            // rather than leaving the space looking broken.
            BrixCard {
                visible: !Net.hasWifi && !Bt.available
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    SectionHeader { text: "WIRELESS"; icon: "󰤭"; Layout.fillWidth: true }

                    Text {
                        Layout.fillWidth: true
                        text: "No wireless card and no Bluetooth adapter on this machine, "
                              + "so this tab is the wired link above. Both sections appear "
                              + "on their own once the hardware exists."
                        wrapMode: Text.WordWrap
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        color: Theme.foregroundDim
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    // ── local helper components ─────────────────────────────────────────────
    // Centred empty state, the same shape the notification centre uses for
    // "all caught up" — centred reads as deliberate, where a line of text
    // stranded at the top of a tall box reads as something failing to load.
    component Placeholder: Item {
        id: phRoot
        property string glyph: ""
        property string label: ""
        property string hint: ""

        ColumnLayout {
            anchors.centerIn: parent
            width: phRoot.width - Theme.spaceMd * 2
            spacing: Theme.spaceXs

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: phRoot.glyph
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXl
                color: Theme.foregroundDim
                opacity: 0.5
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: phRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
            }
            Text {
                Layout.fillWidth: true
                visible: phRoot.hint !== ""
                text: phRoot.hint
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: Theme.foregroundDim
                opacity: 0.8
            }
        }
    }

    // Hard-edged scroll indicator: a list that overflows should say so, and a
    // brutalist bar is a rectangle, not a rounded pill.
    component ScrollTrack: Item {
        id: trackRoot
        property ListView list: null

        implicitWidth: 4
        visible: list !== null && list.contentHeight > list.height + 1

        Rectangle {
            anchors.fill: parent
            color: Theme.outline
            opacity: 0.15
        }

        Rectangle {
            width: parent.width
            color: Theme.primary
            y: trackRoot.list ? trackRoot.list.visibleArea.yPosition * trackRoot.height : 0
            height: trackRoot.list
                    ? Math.max(14, trackRoot.list.visibleArea.heightRatio * trackRoot.height)
                    : 0
        }
    }
}
