// Slim outlined meter used for CPU / RAM / disk rows.
//
// The fill is inset by the border width and rounded to its own height, so it
// sits *inside* the outline like the meters in the Neobrix reference. A plain
// `clip: true` is not enough here: Qt Quick clips to the bounding rectangle, not
// to the rounded shape, so a square fill spilled over the pill's corners and
// painted across the 2px border.

import QtQuick
import qs.Theme

BrixCard {
    id: root

    property real value: 0          // 0..1
    property color accent: Theme.primary

    readonly property real inset: border.width
    readonly property real trackWidth: Math.max(0, width - inset * 2)

    implicitHeight: 12
    implicitWidth: 80
    radius: Theme.radiusPill
    color: Theme.surface
    shadowOffset: 0

    Rectangle {
        x: root.inset
        y: root.inset
        height: Math.max(0, root.height - root.inset * 2)
        width: Math.max(0, Math.min(1, root.value)) * root.trackWidth
        radius: height / 2
        color: root.accent
        antialiasing: true

        Behavior on width {
            NumberAnimation { duration: Theme.durSlow; easing.type: Theme.easing }
        }
    }
}
