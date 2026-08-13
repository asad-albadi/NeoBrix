// Status glyph row: network, bluetooth, audio, microphone, battery.
//
// Each entry is present only when the corresponding hardware/service exists, so
// on this VM the row collapses to network + audio and shows no dead icons.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barIslandHeight - Theme.spaceSm

    readonly property var battery: UPower.displayDevice

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceSm

        // ── audio ───────────────────────────────────────────────────────────
        Glyph {
            glyph: Audio.volumeIcon
            color: Audio.muted ? Theme.error : Theme.foreground
            tooltip: Audio.hasSink
                     ? Audio.sinkName + " · " + Math.round(Audio.volume * 100) + "%"
                       + (Audio.muted ? " (muted)" : "")
                     : "No audio output"
            onClicked: Audio.toggleMute()
            onWheelUp: Audio.stepVolume(0.05)
            onWheelDown: Audio.stepVolume(-0.05)
            onRightClicked: Panels.openControl("system")
        }

        // ── microphone (hidden when there is no capture device) ─────────────
        Glyph {
            visible: Audio.hasSource
            glyph: Audio.micIcon
            color: Audio.micMuted ? Theme.error : Theme.foreground
            tooltip: Audio.sourceName + " · " + Math.round(Audio.micVolume * 100) + "%"
                     + (Audio.micMuted ? " (muted)" : "")
            onClicked: Audio.toggleMicMute()
        }

        // ── bluetooth (hidden without an adapter) ───────────────────────────
        Glyph {
            visible: Bt.available
            glyph: Bt.icon
            color: Bt.enabled ? Theme.foreground : Theme.foregroundDim
            tooltip: "Bluetooth · " + Bt.statusText
            onClicked: Bt.toggle()
            onRightClicked: Panels.openControl("system")
        }

        // ── network ─────────────────────────────────────────────────────────
        Glyph {
            glyph: Net.icon
            color: Net.connected ? (Net.online ? Theme.foreground : Theme.warning) : Theme.error
            tooltip: Net.typeLabel + " · " + Net.connectionName
                     + (Net.connected ? "\n" + Net.interfaceName + "  " + Net.ipv4 : "")
            onClicked: Panels.openControl("system")
        }

        // ── battery (hidden on desktops/VMs) ────────────────────────────────
        RowLayout {
            visible: Hw.hasBattery
            spacing: Theme.spaceXs

            Text {
                text: {
                    if (!root.battery) return "";
                    const p = root.battery.percentage;
                    const charging = root.battery.state === UPowerDeviceState.Charging
                                  || root.battery.state === UPowerDeviceState.FullyCharged;
                    if (charging) return "󰂅";
                    if (p > 0.9) return "󰁹";
                    if (p > 0.7) return "󰂂";
                    if (p > 0.5) return "󰁿";
                    if (p > 0.3) return "󰁽";
                    if (p > 0.15) return "󰁻";
                    return "󰂃";
                }
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLg
                color: root.battery && root.battery.percentage < 0.15
                       ? Theme.error : Theme.foreground
            }
            Text {
                text: root.battery ? Math.round(root.battery.percentage * 100) + "%" : ""
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                font.weight: Theme.weightBold
                color: Theme.foreground
            }
        }
    }

    // Small inline helper so each indicator is one declaration above.
    component Glyph: Item {
        id: glyphRoot
        property string glyph: ""
        property color color: Theme.foreground
        property string tooltip: ""

        signal clicked()
        signal rightClicked()
        signal wheelUp()
        signal wheelDown()

        implicitWidth: 18
        implicitHeight: 18
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        Text {
            anchors.centerIn: parent
            text: glyphRoot.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLg
            color: glyphRoot.color
            opacity: glyphMouse.containsMouse ? 0.65 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        MouseArea {
            id: glyphMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mev => {
                if (mev.button === Qt.RightButton) glyphRoot.rightClicked();
                else glyphRoot.clicked();
            }
            onWheel: wev => {
                if (wev.angleDelta.y > 0) glyphRoot.wheelUp();
                else glyphRoot.wheelDown();
            }
        }

        BrixTooltip {
            text: glyphRoot.tooltip
            visible: glyphMouse.containsMouse && glyphRoot.tooltip !== ""
            anchorItem: glyphRoot
        }
    }
}
