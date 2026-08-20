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
import Quickshell.Bluetooth
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
    // Rows with the passphrase field open. A scan landing mid-typing used to
    // reorder the list under the cursor and take the field's focus with it, so
    // while any row is being edited the scan pauses and the list is frozen.
    property int editingCount: 0
    readonly property bool editing: root.editingCount > 0

    readonly property bool scanning:
        root.active && Net.hasWifi && Net.wifiEnabled && !root.editing
    onScanningChanged: scanning ? Net.beginScan() : Net.endScan()

    // Net.visibleNetworks is ordered by signal strength, which changes on every
    // scan — that is what made rows jump. Order by something that does not move:
    // the connection first, then saved profiles, then name.
    function sortedNetworks() {
        return Net.visibleNetworks.slice().sort((a, b) =>
            (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
            || (b.known ? 1 : 0) - (a.known ? 1 : 0)
            || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
    }

    property var frozenNetworks: null
    readonly property var displayNetworks:
        root.frozenNetworks !== null ? root.frozenNetworks : root.sortedNetworks()
    onEditingChanged: root.frozenNetworks = root.editing ? root.sortedNetworks() : null

    // Both radios are torn down here: QML allows only one handler per signal, so
    // the Wi-Fi scan counter and the Bluetooth discovery flag share it.
    Component.onDestruction: {
        if (root.scanning) Net.endScan();
        if (Bt.available && Bt.discovering) Bt.setDiscovering(false);
    }

    // ── security helpers ────────────────────────────────────────────────────
    // Owe is opportunistic ("enhanced open") encryption with no passphrase, so
    // it counts as open for the purpose of "can I join this by clicking it".
    function secured(sec) {
        return sec !== WifiSecurityType.Open
            && sec !== WifiSecurityType.Owe
            && sec !== WifiSecurityType.Unknown;
    }

    // ── bluetooth discovery ─────────────────────────────────────────────────
    // Discovery is a radio scan and this is a laptop, so it is opt-in *and*
    // bounded by the tab being on screen: leaving the tab stops it and clears
    // the request, so reopening the panel never resumes a scan behind your back.
    property bool scanRequested: false

    readonly property bool discoverWanted:
        root.active && Bt.available && Bt.enabled && root.scanRequested
    onDiscoverWantedChanged: Bt.setDiscovering(root.discoverWanted)
    onActiveChanged: if (!root.active) root.scanRequested = false;

    // Bt.devices is deliberately the paired set, so the full adapter list is
    // read here to separate "known" from "just found".
    readonly property var adapterDevices:
        Bt.adapter && Bt.adapter.devices ? Bt.adapter.devices.values : []
    readonly property var pairedDevices: adapterDevices
        .filter(d => d.paired || d.bonded)
        .sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0))
    // A scan in a populated room is mostly anonymous BLE beacons — seven of them
    // here, all rendering as near-identical rows, which is how a Pair press
    // landed on a beacon and came back "Authentication Canceled". Nothing you
    // want to pair advertises without a name, so unnamed devices are counted
    // rather than listed.
    function btNamed(dev) { return !!(dev && (dev.deviceName || dev.name)); }

    readonly property var discoveredDevices: adapterDevices
        .filter(d => !(d.paired || d.bonded) && root.btNamed(d))
        .sort((a, b) => (root.btLabel(a) < root.btLabel(b) ? -1
                       : root.btLabel(a) > root.btLabel(b) ? 1 : 0))

    readonly property int unnamedNearby: adapterDevices
        .filter(d => !(d.paired || d.bonded) && !root.btNamed(d)).length

    // BlueZ leaves Name unset until it resolves one, so an unnamed advertiser
    // would otherwise render as a blank row.
    function btLabel(dev) {
        if (!dev) return "";
        return dev.deviceName || dev.name || dev.address;
    }

    // BlueZ reports a freedesktop icon name; map the families that matter to
    // glyphs and fall back to the generic Bluetooth mark.
    function btGlyph(icon) {
        const i = icon || "";
        if (i.indexOf("headset") !== -1 || i.indexOf("headphone") !== -1) return "󰋋";
        if (i.indexOf("speaker") !== -1 || i.indexOf("audio") !== -1)     return "󰓃";
        if (i.indexOf("phone") !== -1)                                    return "󰄜";
        if (i.indexOf("computer") !== -1 || i.indexOf("laptop") !== -1)   return "󰇄";
        if (i.indexOf("keyboard") !== -1)                                 return "󰌌";
        if (i.indexOf("mouse") !== -1 || i.indexOf("pointing") !== -1)    return "󰦋";
        if (i.indexOf("gaming") !== -1 || i.indexOf("joystick") !== -1)   return "󰊗";
        if (i.indexOf("printer") !== -1)                                  return "󰐪";
        if (i.indexOf("camera") !== -1)                                   return "󰄄";
        if (i.indexOf("watch") !== -1)                                    return "󱑈";
        if (i.indexOf("display") !== -1 || i.indexOf("tv") !== -1)        return "󰍹";
        return "󰂯";
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
                                return WifiSecurityType.toString(root.activeNetwork.security)
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
                            model: root.displayNetworks
                            clip: true
                            spacing: 2
                            boundsBehavior: Flickable.StopAtBounds

                            delegate: Item {
                                id: netRow
                                required property var modelData

                                readonly property var net: netRow.modelData
                                readonly property bool secured: root.secured(netRow.net.security)
                                // A saved profile already holds the secret, so
                                // NetworkManager needs nothing from us.
                                // Also true once NetworkManager has rejected the
                                // stored secret: a saved profile that cannot
                                // authenticate must be able to ask again, which
                                // is exactly what it could not do before.
                                readonly property bool needsPsk:
                                    netRow.secured && (!netRow.net.known || netRow.secretRejected)

                                property bool secretRejected: false
                                property bool awaitingForget: false
                                property bool askPsk: false
                                property bool showActions: false
                                property string failure: ""

                                width: ListView.view.width
                                height: 34 + (netRow.askPsk || netRow.showActions ? 30 : 0)

                                // Row click: connect where that is all it takes,
                                // otherwise open the passphrase field in place.
                                // A click anywhere on the row opens its actions,
                                // and every action lives in there. Nothing in the
                                // header is clickable, so there is no button for
                                // the row's own MouseArea to sit on top of and
                                // swallow — which is what happened to the actions
                                // button that used to be in the header: the
                                // overlay took the click and joined the network
                                // instead, and on any row but the connected one
                                // the actions could not be reached at all.
                                function toggleActions() {
                                    if (netRow.askPsk) { netRow.askPsk = false; return; }
                                    netRow.showActions = !netRow.showActions;
                                }

                                // The primary action, from the button in the row
                                // the click above opens.
                                function join() {
                                    if (netRow.net.stateChanging) return;
                                    netRow.failure = "";
                                    if (netRow.needsPsk) { netRow.showActions = false; netRow.askPsk = true; return; }
                                    netRow.net.connect();
                                }

                                // The passphrase is handed straight to
                                // NetworkManager and dropped: no property keeps
                                // it, nothing logs it, nothing writes it out.
                                function submitPsk() {
                                    if (pskField.text.length === 0) return;
                                    netRow.failure = "";
                                    // A stored profile whose secret was rejected
                                    // cannot be repaired through connectWithPsk:
                                    // NetworkManager keeps activating the broken
                                    // profile instead. Drop it, then join fresh
                                    // when it is actually gone — sequenced on
                                    // `known`, not on a timer.
                                    if (netRow.net.known) {
                                        netRow.awaitingForget = true;
                                        netRow.net.forget();
                                        return;
                                    }
                                    netRow.net.connectWithPsk(pskField.text);
                                    pskField.text = "";
                                    netRow.askPsk = false;
                                }

                                function closePsk() {
                                    pskField.text = "";
                                    netRow.askPsk = false;
                                }

                                onAskPskChanged: {
                                    if (netRow.askPsk) {
                                        root.editingCount++;
                                    } else {
                                        root.editingCount--;
                                        netRow.awaitingForget = false;
                                        pskField.text = "";
                                    }
                                }
                                Component.onDestruction: if (netRow.askPsk) root.editingCount--;

                                // Leaving the tab must not leave a typed
                                // passphrase sitting in a recycled delegate.
                                Connections {
                                    target: root
                                    function onActiveChanged() {
                                        if (!root.active) {
                                            pskField.text = "";
                                            netRow.askPsk = false;
                                            netRow.showActions = false;
                                        }
                                    }
                                }

                                // The real reason, from NetworkManager, rather
                                // than a silent failure: a wrong passphrase
                                // arrives here as NoSecrets.
                                Connections {
                                    target: netRow.net
                                    function onConnectionFailed(reason) {
                                        netRow.failure = ConnectionFailReason.toString(reason);
                                        if (netRow.secured && reason === ConnectionFailReason.NoSecrets) {
                                            netRow.secretRejected = true;
                                            netRow.askPsk = true;
                                        }
                                    }
                                    function onConnectedChanged() {
                                        if (netRow.net.connected) {
                                            netRow.failure = "";
                                            netRow.secretRejected = false;
                                            netRow.closePsk();
                                        }
                                    }
                                    // The second half of a "forget, then join":
                                    // the passphrase never leaves the field, so
                                    // nothing holds it across the round trip.
                                    function onKnownChanged() {
                                        if (!netRow.net.known && netRow.awaitingForget) {
                                            netRow.awaitingForget = false;
                                            netRow.net.connectWithPsk(pskField.text);
                                            pskField.text = "";
                                            netRow.askPsk = false;
                                        }
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radiusXs
                                    color: netRow.net.connected ? Theme.secondary
                                         : netRow.askPsk || netRow.showActions ? Theme.surfaceDeep
                                         : netMouse.containsMouse ? Theme.surfaceDeep : "transparent"
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceXs
                                    anchors.rightMargin: Theme.spaceXs
                                    spacing: 0

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 34
                                        spacing: Theme.spaceXs

                                        Text {
                                            text: Net.glyphFor(netRow.net.signalStrength)
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontMd
                                            color: netRow.net.connected
                                                   ? Theme.textOn(Theme.secondary) : Theme.foreground
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: -2

                                            Text {
                                                Layout.fillWidth: true
                                                text: netRow.net.name
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSm
                                                font.weight: Theme.weightBold
                                                color: netRow.net.connected
                                                       ? Theme.textOn(Theme.secondary) : Theme.foreground
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: {
                                                    if (netRow.failure !== "") return netRow.failure;
                                                    if (netRow.net.stateChanging)
                                                        return ConnectionState.toString(netRow.net.state) + "…";
                                                    const parts = [WifiSecurityType.toString(netRow.net.security)];
                                                    parts.push(Net.percentFor(netRow.net.signalStrength) + "%");
                                                    return parts.join(" · ");
                                                }
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 8
                                                font.weight: netRow.failure !== ""
                                                             ? Theme.weightBold : Theme.weightNormal
                                                color: netRow.failure !== "" ? Theme.error
                                                     : netRow.net.connected
                                                       ? Theme.textOn(Theme.secondary) : Theme.foregroundDim
                                            }
                                        }

                                        // Encryption, not "saved" — the lock used
                                        // to mark `known`, which is what the
                                        // SAVED chip says.
                                        Text {
                                            visible: netRow.secured
                                            text: "󰌾"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSm
                                            color: netRow.net.connected
                                                   ? Theme.textOn(Theme.secondary) : Theme.foregroundDim
                                        }

                                        BrixChip {
                                            visible: !netRow.secured
                                            text: "OPEN"
                                            fontSize: 8
                                            accent: Theme.warning
                                        }

                                        BrixChip {
                                            visible: netRow.net.known && !netRow.net.connected
                                            text: "SAVED"
                                            fontSize: 8
                                            accent: Theme.surfaceDeep
                                        }

                                        BrixChip {
                                            visible: netRow.net.connected || netRow.net.stateChanging
                                            text: netRow.net.stateChanging
                                                  ? ConnectionState.toString(netRow.net.state).toUpperCase()
                                                  : "CONNECTED"
                                            fontSize: 8
                                            accent: Theme.surface
                                        }
                                    }

                                    // ── passphrase, inline ──────────────────
                                    RowLayout {
                                        visible: netRow.askPsk
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        spacing: Theme.spaceXs

                                        BrixCard {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 24
                                            radius: Theme.radiusXs
                                            color: Theme.surface
                                            shadowOffset: 0

                                            TextInput {
                                                id: pskField
                                                anchors.fill: parent
                                                anchors.leftMargin: Theme.spaceXs
                                                anchors.rightMargin: Theme.spaceXs
                                                verticalAlignment: TextInput.AlignVCenter
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontXs
                                                color: Theme.foreground
                                                selectionColor: Theme.primary
                                                selectedTextColor: Theme.onAccent
                                                clip: true
                                                // A passphrase is a secret: never
                                                // shown, never persisted, never
                                                // passed through a shell.
                                                echoMode: TextInput.Password
                                                passwordCharacter: "•"
                                                focus: netRow.askPsk
                                                activeFocusOnTab: true

                                                Text {
                                                    visible: pskField.text === ""
                                                    anchors.left: parent.left
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "Passphrase"
                                                    font: pskField.font
                                                    color: Theme.foregroundDim
                                                }

                                                Keys.onPressed: ev => {
                                                    if (ev.key === Qt.Key_Escape) {
                                                        netRow.closePsk();
                                                        ev.accepted = true;
                                                    } else if (ev.key === Qt.Key_Return
                                                               || ev.key === Qt.Key_Enter) {
                                                        netRow.submitPsk();
                                                        ev.accepted = true;
                                                    }
                                                }
                                            }
                                        }

                                        BrixButton {
                                            text: netRow.net.known ? "Forget & join" : "Join"
                                            fontSize: 8
                                            vPadding: 2
                                            accent: Theme.primary
                                            enabled: pskField.text.length > 0
                                            onClicked: netRow.submitPsk()
                                        }
                                        BrixButton {
                                            text: "Cancel"
                                            fontSize: 8
                                            vPadding: 2
                                            accent: Theme.surfaceAlt
                                            onClicked: netRow.closePsk()
                                        }
                                    }

                                    // ── per-network actions ─────────────────
                                    RowLayout {
                                        visible: netRow.showActions
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 28
                                        spacing: Theme.spaceXs

                                        BrixButton {
                                            visible: !netRow.net.connected
                                            text: netRow.needsPsk ? "Join with passphrase" : "Connect"
                                            fontSize: 8
                                            vPadding: 2
                                            accent: Theme.surfaceAlt
                                            onClicked: {
                                                netRow.showActions = false;
                                                netRow.join();
                                            }
                                        }
                                        BrixButton {
                                            visible: netRow.net.connected
                                            text: "Disconnect"
                                            fontSize: 8
                                            vPadding: 2
                                            accent: Theme.surfaceAlt
                                            onClicked: {
                                                netRow.showActions = false;
                                                netRow.net.disconnect();
                                            }
                                        }
                                        BrixButton {
                                            visible: netRow.net.known
                                            text: "Forget"
                                            fontSize: 8
                                            vPadding: 2
                                            accent: Theme.error
                                            onClicked: {
                                                netRow.showActions = false;
                                                netRow.net.forget();
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }
                                }

                                MouseArea {
                                    id: netMouse
                                    anchors.fill: parent
                                    anchors.bottomMargin: netRow.askPsk || netRow.showActions ? 30 : 0
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: netRow.toggleActions()
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

                        BrixButton {
                            visible: Bt.enabled
                            text: Bt.discovering ? "Stop" : "Scan"
                            icon: Bt.discovering ? "󰄮" : "󰐷"
                            fontSize: 8
                            vPadding: 2
                            active: Bt.discovering
                            activeAccent: Theme.info
                            accent: Theme.surfaceAlt
                            onClicked: root.scanRequested = !root.scanRequested
                        }

                        BrixToggle {
                            checked: Bt.enabled
                            accent: Theme.info
                            onToggled: on => Bt.setEnabled(on)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!Bt.enabled) return "Adapter off";
                            const parts = [Bt.statusText];
                            if (Bt.discovering) parts.push("scanning");
                            if (root.discoveredDevices.length > 0)
                                parts.push(root.discoveredDevices.length + " nearby");
                            if (root.unnamedNearby > 0)
                                parts.push(root.unnamedNearby + " unnamed hidden");
                            return parts.join(" · ");
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.foregroundDim
                    }

                    // Paired and discovered share one scroll area, so a long
                    // nearby list cannot push the paired devices out of reach.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: Bt.enabled
                                 && (root.pairedDevices.length > 0 || root.discoveredDevices.length > 0)
                        spacing: Theme.spaceXs

                        Flickable {
                            id: btFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: btColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: btColumn
                                width: btFlick.width
                                spacing: 2

                                SectionHeader {
                                    visible: root.pairedDevices.length > 0
                                    text: "PAIRED"
                                    Layout.fillWidth: true
                                }

                                Repeater {
                                    model: root.pairedDevices
                                    delegate: BtRow { required property var modelData; dev: modelData }
                                }

                                SectionHeader {
                                    visible: root.discoveredDevices.length > 0
                                    text: "NEARBY"
                                    Layout.fillWidth: true
                                }

                                Repeater {
                                    model: root.discoveredDevices
                                    delegate: BtRow { required property var modelData; dev: modelData }
                                }
                            }
                        }

                        ScrollTrack { list: btFlick; Layout.fillHeight: true }
                    }

                    Placeholder {
                        visible: !Bt.enabled
                                 || (root.pairedDevices.length === 0 && root.discoveredDevices.length === 0)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        glyph: Bt.enabled ? "󰂯" : "󰂲"
                        label: !Bt.enabled ? "adapter off"
                             : Bt.discovering ? "scanning…" : "no devices"
                        hint: !Bt.enabled ? ""
                            : Bt.discovering ? "put the device in pairing mode"
                            : "press Scan to look for devices nearby"
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
    // One Bluetooth device: primary action inline, the rest behind the dots so
    // a row stays a row. Everything here is a BlueZ method on the device object
    // itself — no bluetoothctl, no process spawn.
    component BtRow: Item {
        id: btRow
        property var dev: null

        readonly property bool isPaired: btRow.dev && (btRow.dev.paired || btRow.dev.bonded)
        property bool showActions: false

        // Quickshell logs BlueZ's pairing error but exposes no signal carrying
        // it, so failure is inferred from the state it leaves behind: `pairing`
        // dropped without `paired` coming up. Without this the attempt failed
        // silently in the UI and the reason only reached the journal.
        property bool pairAttempted: false
        property bool pairFailed: false

        Connections {
            target: btRow.dev
            function onPairingChanged() {
                if (!btRow.dev) return;
                if (btRow.dev.pairing) {
                    btRow.pairAttempted = true;
                    btRow.pairFailed = false;
                } else if (btRow.pairAttempted && !btRow.isPaired) {
                    btRow.pairFailed = true;
                }
            }
            function onPairedChanged() {
                if (btRow.isPaired) {
                    btRow.pairFailed = false;
                    btRow.pairAttempted = false;
                }
            }
        }

        Layout.fillWidth: true
        implicitHeight: 34 + (btRow.showActions ? 30 : 0)

        Connections {
            target: root
            function onActiveChanged() { if (!root.active) btRow.showActions = false; }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusXs
            color: btRow.dev && btRow.dev.connected ? Theme.info
                 : btRow.showActions ? Theme.surfaceDeep
                 : btMouse.containsMouse ? Theme.surfaceDeep : "transparent"
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXs
            anchors.rightMargin: Theme.spaceXs
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                spacing: Theme.spaceXs

                Text {
                    text: root.btGlyph(btRow.dev ? btRow.dev.icon : "")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMd
                    color: btRow.dev && btRow.dev.connected
                           ? Theme.textOn(Theme.info) : Theme.foreground
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    Text {
                        Layout.fillWidth: true
                        text: root.btLabel(btRow.dev)
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSm
                        font.weight: Theme.weightBold
                        color: btRow.dev && btRow.dev.connected
                               ? Theme.textOn(Theme.info) : Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!btRow.dev) return "";
                            if (btRow.pairFailed)
                                return "pairing failed — check it is in pairing mode, or Forget "
                                     + "it and rescan; a PIN or number-match device needs "
                                     + "bluetoothctl once";
                            const parts = [BluetoothDeviceState.toString(btRow.dev.state).toLowerCase()];
                            // battery is 0..1, like signalStrength: BlueZ
                            // reported 99 for a headset while this property read
                            // 0.99, checked side by side.
                            if (btRow.dev.batteryAvailable)
                                parts.push("battery " + Math.round(btRow.dev.battery * 100) + "%");
                            if (btRow.dev.trusted) parts.push("trusted");
                            return parts.join(" · ");
                        }
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: btRow.pairFailed ? Theme.weightBold : Theme.weightNormal
                        color: btRow.pairFailed ? Theme.error
                             : btRow.dev && btRow.dev.connected
                               ? Theme.textOn(Theme.info) : Theme.foregroundDim
                    }
                }

                BrixChip {
                    visible: btRow.dev && btRow.dev.batteryAvailable
                    text: btRow.dev ? Math.round(btRow.dev.battery * 100) + "%" : ""
                    fontSize: 8
                    accent: Theme.secondary
                }
            }

            // Every action, reached by clicking the row. Nothing above is
            // clickable: the header buttons used to sit here and would now be
            // covered by the row's own MouseArea, which is the bug this layout
            // removes rather than works around.
            RowLayout {
                visible: btRow.showActions
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: Theme.spaceXs

                // Pairing is cancellable while it is in flight, which matters
                // when the other end is waiting on a confirmation nothing here
                // can answer.
                BrixButton {
                    visible: btRow.dev && btRow.dev.pairing
                    text: "Cancel"
                    fontSize: 8
                    vPadding: 2
                    accent: Theme.warning
                    onClicked: btRow.dev.cancelPair()
                }
                BrixButton {
                    visible: btRow.dev && !btRow.dev.pairing && !btRow.isPaired
                    text: "Pair"
                    fontSize: 8
                    vPadding: 2
                    accent: Theme.primary
                    onClicked: btRow.dev.pair()
                }
                BrixButton {
                    visible: btRow.dev && !btRow.dev.pairing && btRow.isPaired
                    text: btRow.dev && btRow.dev.connected ? "Disconnect" : "Connect"
                    fontSize: 8
                    vPadding: 2
                    accent: btRow.dev && btRow.dev.connected ? Theme.surface : Theme.surfaceAlt
                    onClicked: {
                        if (btRow.dev.connected) btRow.dev.disconnect();
                        else btRow.dev.connect();
                    }
                }

                Text {
                    text: "Trust"
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Theme.weightBold
                    color: btRow.dev && btRow.dev.connected
                           ? Theme.textOn(Theme.info) : Theme.foregroundDim
                }
                BrixToggle {
                    checked: btRow.dev ? btRow.dev.trusted : false
                    accent: Theme.info
                    onToggled: on => { if (btRow.dev) btRow.dev.trusted = on; }
                }

                BrixButton {
                    text: "Forget"
                    fontSize: 8
                    vPadding: 2
                    accent: Theme.error
                    onClicked: {
                        btRow.showActions = false;
                        btRow.dev.forget();
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        MouseArea {
            id: btMouse
            anchors.fill: parent
            anchors.bottomMargin: btRow.showActions ? 30 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btRow.showActions = !btRow.showActions
        }
    }

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
        // Flickable, not ListView: the Wi-Fi side is a ListView and the
        // Bluetooth side a Flickable holding two sections.
        property Flickable list: null

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
