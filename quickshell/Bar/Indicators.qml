// Status glyph row: audio, microphone, bluetooth, network, battery.
//
// Each entry is present only when the corresponding hardware/service exists, so
// on a machine without them the row collapses and shows no dead icons. That is
// also why a popover is told where to appear instead of working it out from a
// fixed offset: which glyphs exist decides where any of them sits.
//
// Left-click opens that indicator's own popover; right-click still goes to the
// Control Center, which shows the same state with everything else around it.

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
            popover: "audio"
            // Mute stays on the wheel-click, since the popover is one click
            // away and muting from the bar was worth a single gesture.
            onMiddleClicked: Audio.toggleMute()
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
            popover: "mic"
            onMiddleClicked: Audio.toggleMicMute()
            onRightClicked: Panels.openControl("system")
        }

        // ── bluetooth (hidden without an adapter) ───────────────────────────
        Glyph {
            visible: Bt.available
            glyph: Bt.icon
            color: Bt.enabled ? Theme.foreground : Theme.foregroundDim
            tooltip: "Bluetooth · " + Bt.statusText
            // No popover yet: the device list it would render lives in
            // ConnectivityTab, which does not yet know how to show one radio on
            // its own. Until it does, this opens the tab that has the list.
            onClicked: Panels.openControl("connectivity")
            onMiddleClicked: Bt.toggle()
        }

        // ── network ─────────────────────────────────────────────────────────
        Glyph {
            glyph: Net.icon
            color: Net.connected ? (Net.online ? Theme.foreground : Theme.warning) : Theme.error
            tooltip: Net.typeLabel + " · " + Net.connectionName
                     + (Net.connected ? "\n" + Net.interfaceName + "  " + Net.ipv4 : "")
            onClicked: Panels.openControl("connectivity")
        }

        // ── battery (hidden on desktops/VMs) ────────────────────────────────
        // Wrapped in a Glyph so the charge and the power profile are reachable
        // from it; the icon and the percentage were previously inert.
        Glyph {
            visible: Hw.hasBattery
            popover: "power"
            tooltip: root.battery
                     ? Math.round(root.battery.percentage * 100) + "% · power profile"
                     : "Battery"
            onRightClicked: Panels.openControl("system")

            implicitWidth: batteryRow.implicitWidth
            implicitHeight: 18

        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
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
    }

    // Small inline helper so each indicator is one declaration above.
    component Glyph: Item {
        id: glyphRoot
        property string glyph: ""
        property color color: Theme.foreground
        property string tooltip: ""
        // Panel name of this indicator's popover, "" for one without.
        property string popover: ""

        signal clicked()
        signal rightClicked()
        signal middleClicked()
        signal wheelUp()
        signal wheelDown()

        // Screen x of this glyph's centre. The bar spans the full width and its
        // window origin is 0, so a point in window coordinates is already a
        // point on screen — and asking the item where it actually is keeps the
        // popover under it however many neighbours are hidden.
        //
        // A function, not a bound property: mapToItem is a call QML cannot track
        // dependencies for, so as a binding it evaluated once at creation —
        // before the layout had placed anything — and every popover opened at
        // x = 0, against the left edge of the screen.
        function centreX() {
            return glyphRoot.mapToItem(null, glyphRoot.width / 2, 0).x;
        }

        readonly property bool popoverOpen: popover !== "" && Panels.isOpen(popover)

        implicitWidth: 18
        implicitHeight: 18
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        Text {
            anchors.centerIn: parent
            text: glyphRoot.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLg
            color: glyphRoot.popoverOpen ? Theme.primary : glyphRoot.color
            opacity: glyphMouse.containsMouse ? 0.65 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        MouseArea {
            id: glyphMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mev => {
                if (mev.button === Qt.RightButton) {
                    glyphRoot.rightClicked();
                } else if (mev.button === Qt.MiddleButton) {
                    glyphRoot.middleClicked();
                } else if (glyphRoot.popover !== "") {
                    Panels.togglePopover(glyphRoot.popover, glyphRoot.centreX());
                } else {
                    glyphRoot.clicked();
                }
            }
            onWheel: wev => {
                if (wev.angleDelta.y > 0) glyphRoot.wheelUp();
                else glyphRoot.wheelDown();
            }
        }

        BrixTooltip {
            text: glyphRoot.tooltip
            visible: glyphMouse.containsMouse && glyphRoot.tooltip !== ""
                     && !glyphRoot.popoverOpen
            anchorItem: glyphRoot
        }
    }
}
