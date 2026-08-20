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

    // The colour of the island this sits on, so the glyph can be drawn against
    // it rather than against the bar.
    property color accent: Theme.pink

    implicitWidth: 22
    implicitHeight: 22

    Text {
        anchors.centerIn: parent
        text: "󰒓"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLg
        // Theme.foreground is the page's ink: light in dusk, which put a white
        // glyph on a pink island and left it barely legible. textOn picks the
        // ink for the surface it is actually on — both pink and primary are
        // light in both palettes, so this is black either way, without a colour
        // being written down here.
        color: Theme.textOn(root.accent)
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
