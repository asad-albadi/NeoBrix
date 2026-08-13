// Small non-interactive label pill — "ARCH LINUX", "● Online", "88%".

import QtQuick
import QtQuick.Layouts
import qs.Theme

Item {
    id: root

    property string text: ""
    property string icon: ""
    property color accent: Theme.secondary
    property color textColor: Theme.textOn(accent)
    property int fontSize: Theme.fontXs
    property int shadowOffset: 0
    property int radius: Theme.radiusPill

    implicitWidth: row.implicitWidth + Theme.spaceMd
    implicitHeight: row.implicitHeight + Theme.spaceXs * 2

    BrixCard {
        id: card
        anchors.fill: parent
        radius: root.radius
        color: root.accent
        shadowOffset: root.shadowOffset
    }

    RowLayout {
        id: row
        parent: card
        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            color: root.textColor
        }
        Text {
            visible: root.text !== ""
            text: root.text
            font.family: Theme.fontFamily
            font.pixelSize: root.fontSize
            font.weight: Theme.weightBold
            color: root.textColor
        }
    }
}
