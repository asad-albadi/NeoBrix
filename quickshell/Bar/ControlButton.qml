// Control centre opener. Occupies the separate island at the end of the bar —
// the notification bell used to sit here, and moved into the segment when every
// indicator gained a control of its own; this is the one thing left that opens a
// full panel rather than a popover.

import QtQuick
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    implicitWidth: 22
    implicitHeight: 22

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLg
        color: Theme.foreground
        opacity: mouse.containsMouse ? 0.65 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggleControl("system")
    }

    BrixTooltip {
        text: "Control centre  ·  SUPER + X"
        visible: mouse.containsMouse && !Panels.isOpen("control")
        anchorItem: root
    }
}
