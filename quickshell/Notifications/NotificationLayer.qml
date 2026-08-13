// Toast layer.
//
// A narrow top-right strip rather than a full-screen overlay, with an input mask
// limited to the toasts themselves so the rest of the desktop stays clickable
// even while notifications are on screen.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Components
import qs.Services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        readonly property bool hasPopups: Notifs.popups.length > 0
        visible: hasPopups

        anchors { top: true; right: true }
        margins.top: Theme.barExclusive
        margins.right: Theme.barMargin
        implicitWidth: 360
        implicitHeight: Math.max(1, column.implicitHeight + Theme.spaceMd)
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "neobrix-notifications"

        // Only the cards accept input; the gaps around them pass clicks through.
        mask: Region {
            item: column
        }

        ColumnLayout {
            id: column
            anchors.top: parent.top
            anchors.right: parent.right
            width: parent.width - Theme.shadowMd
            spacing: Theme.spaceSm

            Repeater {
                model: Notifs.popups

                delegate: NotificationItem {
                    required property var modelData
                    Layout.fillWidth: true
                    wrapper: modelData
                    popup: true
                    onDismissed: Notifs.dismissPopup(modelData)
                }
            }
        }
    }
}
