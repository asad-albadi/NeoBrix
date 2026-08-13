// Square/pill icon-only button. Accepts either a nerd-font glyph (`icon`) or a
// freedesktop icon name (`iconName`, resolved through the active icon theme).

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Theme

Item {
    id: root

    property string icon: ""
    property string iconName: ""
    property color accent: Theme.surface
    property color iconColor: Theme.foreground
    property bool active: false
    property color activeAccent: Theme.primary
    property int size: 26
    property int radius: Theme.radiusSm
    property int iconSize: Math.round(size * 0.55)
    property int shadowOffset: Theme.shadowSm
    property bool enabled: true
    property string tooltip: ""
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed
    property alias containsMouse: mouse.containsMouse

    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(int delta)

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.4

    BrixCard {
        id: card
        anchors.fill: parent
        radius: root.radius
        shadowOffset: root.pressed ? 0 : root.shadowOffset
        x: root.pressed ? root.shadowOffset : 0
        y: root.pressed ? root.shadowOffset : 0
        color: root.active ? root.activeAccent
             : root.hovered ? Qt.darker(root.accent, Theme.dark ? 0.85 : 1.06)
             : root.accent
        border.width: root.active ? Theme.borderThick : Theme.border

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
        Behavior on y { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }

        Text {
            visible: root.icon !== ""
            anchors.centerIn: parent
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: root.iconSize
            color: root.active ? Theme.textOn(root.activeAccent) : root.iconColor
        }

        IconImage {
            visible: root.iconName !== ""
            anchors.centerIn: parent
            implicitSize: root.iconSize + 2
            source: root.iconName !== "" ? Quickshell.iconPath(root.iconName, true) : ""
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mev => {
            if (mev.button === Qt.RightButton) root.rightClicked();
            else if (mev.button === Qt.MiddleButton) root.middleClicked();
            else root.clicked();
        }
        onWheel: wev => root.wheel(wev.angleDelta.y)
    }

    BrixTooltip {
        text: root.tooltip
        visible: root.tooltip !== "" && mouse.containsMouse
        anchorItem: root
    }
}
