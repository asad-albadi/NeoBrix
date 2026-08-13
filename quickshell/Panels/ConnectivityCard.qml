// Network and Bluetooth.
//
// The Wi-Fi block only exists when a wireless device is present, and the whole
// Bluetooth block only exists when BlueZ reports an adapter — on this VM the card
// shows the wired connection alone.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixCard {
    id: root

    radius: Theme.radiusMd
    color: Theme.surface
    shadowOffset: Theme.shadowSm
    clip: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        SectionHeader { text: "CONNECTIVITY"; icon: "󰛳"; Layout.fillWidth: true }

        // ── active connection summary ───────────────────────────────────────
        BrixCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Theme.radiusXs
            color: Theme.surfaceAlt
            shadowOffset: 0

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceXs
                anchors.rightMargin: Theme.spaceXs
                spacing: Theme.spaceSm

                BrixCard {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: Theme.radiusXs
                    shadowOffset: 0
                    color: Net.connected ? Theme.secondary : Theme.error

                    Text {
                        anchors.centerIn: parent
                        text: Net.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMd
                        color: Theme.onAccent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -1

                    Text {
                        Layout.fillWidth: true
                        text: Net.connectionName
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSm
                        font.weight: Theme.weightBold
                        color: Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Net.typeLabel + " · " + Net.interfaceName
                              + (Net.ipv4 !== "—" ? " · " + Net.ipv4 : "")
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

        // ── wifi (only with a wireless device) ──────────────────────────────
        RowLayout {
            visible: Net.hasWifi
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Text {
                text: "Wi-Fi"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                font.weight: Theme.weightBold
                color: Theme.foreground
            }
            Item { Layout.fillWidth: true }
            BrixToggle {
                checked: Net.wifiEnabled
                onToggled: on => Net.setWifiEnabled(on)
            }
        }

        ListView {
            visible: Net.hasWifi && Net.wifiEnabled
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? Math.min(110, contentHeight) : 0
            model: Net.visibleNetworks
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds

            Component.onCompleted: if (Net.hasWifi) Net.beginScan()
            Component.onDestruction: if (Net.hasWifi) Net.endScan()

            delegate: Item {
                id: netRow
                required property var modelData
                width: ListView.view.width
                height: 24

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
                        text: {
                            const s = netRow.modelData.signalStrength || 0;
                            if (s > 75) return "󰤨";
                            if (s > 50) return "󰤥";
                            if (s > 25) return "󰤢";
                            return "󰤟";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSm
                        color: Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: netRow.modelData.name
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        font.weight: Theme.weightBold
                        color: Theme.foreground
                    }
                    Text {
                        visible: netRow.modelData.known
                        text: "󰌾"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        color: Theme.foregroundDim
                    }
                }

                MouseArea {
                    id: netMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (netRow.modelData.connected) netRow.modelData.disconnect();
                        else netRow.modelData.connect();
                    }
                }
            }
        }

        // ── bluetooth (only with an adapter) ────────────────────────────────
        RowLayout {
            visible: Bt.available
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Text {
                text: "Bluetooth"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                font.weight: Theme.weightBold
                color: Theme.foreground
            }
            Text {
                text: Bt.statusText
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: Theme.foregroundDim
                Layout.fillWidth: true
            }
            BrixToggle {
                checked: Bt.enabled
                accent: Theme.info
                onToggled: on => Bt.setEnabled(on)
            }
        }

        Repeater {
            model: Bt.available && Bt.enabled ? Bt.devices : []

            delegate: RowLayout {
                id: btRow
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Text {
                    text: btRow.modelData.connected ? "󰂱" : "󰂯"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSm
                    color: Theme.foreground
                }
                Text {
                    Layout.fillWidth: true
                    text: btRow.modelData.deviceName
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    color: Theme.foreground
                }
                BrixButton {
                    text: btRow.modelData.connected ? "Disconnect" : "Connect"
                    fontSize: 8
                    vPadding: 2
                    accent: Theme.surfaceAlt
                    onClicked: {
                        if (btRow.modelData.connected) btRow.modelData.disconnect();
                        else btRow.modelData.connect();
                    }
                }
            }
        }

        // Explicit note when neither radio exists, so the empty space is
        // intentional rather than looking like a failure.
        Text {
            visible: !Net.hasWifi && !Bt.available
            Layout.fillWidth: true
            text: "No wireless or bluetooth hardware on this machine."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 8
            color: Theme.foregroundDim
        }

        Item { Layout.fillHeight: true }
    }
}
