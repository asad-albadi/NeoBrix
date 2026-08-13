// Small caps section label with a hairline rule, used inside dashboard cards.

import QtQuick
import QtQuick.Layouts
import qs.Theme

RowLayout {
    id: root

    property string text: ""
    property string icon: ""

    spacing: Theme.spaceSm

    Text {
        visible: root.icon !== ""
        text: root.icon
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSm
        color: Theme.foregroundDim
    }

    Text {
        text: root.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontXs
        font.weight: Theme.weightHeavy
        font.letterSpacing: 1
        color: Theme.foregroundDim
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.border
        color: Theme.outline
        opacity: 0.25
    }
}
