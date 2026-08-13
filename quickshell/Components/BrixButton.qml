// Chunky text (optionally icon+text) button.
//
// Interaction feedback is physical rather than decorative: on press the card
// travels into its own shadow, which is the neo-brutalist idiom.

import QtQuick
import QtQuick.Layouts
import qs.Theme

Item {
    id: root

    property string text: ""
    property string icon: ""            // nerd-font glyph
    property color accent: Theme.surface
    property color textColor: Theme.foreground
    property bool active: false
    property color activeAccent: Theme.primary
    property int radius: Theme.radiusSm
    property int hPadding: Theme.spaceMd
    property int vPadding: Theme.spaceSm
    property int fontSize: Theme.fontMd
    property int shadowOffset: Theme.shadowSm
    property bool enabled: true
    property alias hovered: mouse.containsMouse
    property alias pressed: mouse.pressed

    signal clicked()
    signal rightClicked()

    implicitWidth: row.implicitWidth + hPadding * 2
    implicitHeight: Math.max(row.implicitHeight + vPadding * 2, 24)
    opacity: enabled ? 1 : 0.45

    BrixCard {
        id: card
        anchors.fill: parent
        radius: root.radius
        shadowOffset: root.pressed ? 0 : root.shadowOffset
        // Travel into the shadow on press.
        x: root.pressed ? root.shadowOffset : 0
        y: root.pressed ? root.shadowOffset : 0
        color: root.active ? root.activeAccent
             : root.hovered ? Qt.darker(root.accent, Theme.dark ? 0.85 : 1.06)
             : root.accent
        border.width: root.active ? Theme.borderThick : Theme.border

        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on x { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
        Behavior on y { NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
    }

    RowLayout {
        id: row
        parent: card
        anchors.centerIn: parent
        spacing: Theme.spaceSm

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize + 2
            color: root.active ? Theme.textOn(root.activeAccent) : root.textColor
        }

        Text {
            visible: root.text !== ""
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.weight: Theme.weightBold
            color: root.active ? Theme.textOn(root.activeAccent) : root.textColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mev => {
            if (mev.button === Qt.RightButton) root.rightClicked();
            else root.clicked();
        }
    }
}
