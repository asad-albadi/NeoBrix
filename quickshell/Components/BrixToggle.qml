// Hard-edged on/off switch. The knob snaps rather than glides.

import QtQuick
import qs.Theme

Item {
    id: root

    property bool checked: false
    property color accent: Theme.secondary
    property bool enabled: true

    signal toggled(bool checked)

    implicitWidth: 44
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusPill
        color: root.checked ? root.accent : Theme.surfaceDeep
        shadowOffset: Theme.shadowSm
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        Rectangle {
            width: parent.height - Theme.spaceXs * 2
            height: width
            radius: Theme.radiusPill
            color: Theme.surface
            border.width: Theme.border
            border.color: Theme.outline
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - Theme.spaceXs : Theme.spaceXs
            Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
