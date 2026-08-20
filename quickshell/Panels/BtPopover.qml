// Bluetooth, hanging under its own glyph in the bar.
//
// The body is ConnectivityTab in "bluetooth" mode — the same component the control
// centre renders, not a second copy of the list. These rows had a click-handling
// bug that took a live test to find; one copy means one place to fix.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "bluetooth"
    alignment: "topAnchor"
    anchorX: Panels.popoverAnchorX
    scrimEnabled: false
    contentWidth: 340
    contentHeight: 400

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        ConnectivityTab {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            show: "bluetooth"
            // Scanning and the frozen-list behaviour key off this, exactly as
            // the control centre tab does.
            active: root.open
        }
    }
}
