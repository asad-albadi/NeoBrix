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

    Component.onDestruction: if (root.scanning) Net.endScan();

    // ── security helpers ────────────────────────────────────────────────────
    // Owe is opportunistic ("enhanced open") encryption with no passphrase, so
    // it counts as open for the purpose of "can I join this by clicking it".
    function secured(sec) {
        return sec !== WifiSecurityType.Open
            && sec !== WifiSecurityType.Owe
            && sec !== WifiSecurityType.Unknown;
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
                                function activate() {
                                    if (netRow.net.stateChanging) return;
                                    if (netRow.net.connected) { netRow.showActions = !netRow.showActions; return; }
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

                                        BrixIconButton {
                                            icon: "󰇘"
                                            tooltip: "Actions"
                                            size: 20
                                            accent: "transparent"
                                            iconColor: netRow.net.connected
                                                       ? Theme.textOn(Theme.secondary) : Theme.foregroundDim
                                            onClicked: {
                                                netRow.askPsk = false;
                                                netRow.showActions = !netRow.showActions;
                                            }
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
                                                netRow.activate();
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
                                    onClicked: netRow.activate()
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
