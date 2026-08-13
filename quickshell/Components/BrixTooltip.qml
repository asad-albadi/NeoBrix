// Tooltip rendered in its own popup surface so it is never clipped by the thin
// bar window it is anchored inside.

import QtQuick
import Quickshell
import qs.Theme

PopupWindow {
    id: root

    property string text: ""
    property Item anchorItem: null
    property int gap: Theme.spaceSm

    anchor.item: anchorItem
    anchor.rect.x: anchorItem ? Math.round(anchorItem.width / 2 - implicitWidth / 2) : 0
    anchor.rect.y: anchorItem ? anchorItem.height + gap : 0
    anchor.adjustment: PopupAdjustment.SlideX

    implicitWidth: label.implicitWidth + Theme.spaceMd * 2
    implicitHeight: label.implicitHeight + Theme.spaceSm * 2 + Theme.shadowSm
    color: "transparent"

    BrixCard {
        width: root.implicitWidth - Theme.shadowSm
        height: root.implicitHeight - Theme.shadowSm
        radius: Theme.radiusSm
        shadowOffset: Theme.shadowSm
        color: Theme.surfaceDeep

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSm
            font.weight: Theme.weightBold
            color: Theme.foreground
        }
    }
}
