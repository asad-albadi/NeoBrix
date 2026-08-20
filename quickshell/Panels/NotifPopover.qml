// Notifications, hanging under the bell in the bar.
//
// The body is NotificationCenter, the same component the control centre renders
// on its notifications tab. SUPER + A still opens that tab: a keybind has no
// glyph to hang a popover under, and guessing an anchor would put the card
// somewhere arbitrary.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "notifications"
    alignment: "topAnchor"
    anchorX: Panels.popoverAnchorX
    scrimEnabled: false
    contentWidth: 380
    contentHeight: 440

    onPanelOpened: Notifs.markAllRead()

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        NotificationCenter {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
        }
    }
}
