// A value picked from a list.
//
// Expands in place rather than floating a popup over its neighbours. A floating
// list has to escape the card it sits in, which means either a second window or
// reparenting to the panel root and reasoning about z-order and clipping; a list
// that pushes the layout down needs neither, and inside a panel this size the
// difference is invisible to the person using it. It scrolls once the list is
// taller than maxListHeight, so a monitor advertising twenty modes still fits.

import QtQuick
import QtQuick.Layouts
import qs.Theme

ColumnLayout {
    id: root

    // Either plain strings, or objects with `label` and `value`.
    property var options: []
    property var value: undefined
    property string placeholder: "—"
    property int maxListHeight: 132
    property bool enabled: true
    property bool open: false

    signal picked(var value)

    spacing: Theme.spaceXs

    function labelOf(opt) { return opt !== null && typeof opt === "object" ? opt.label : opt; }
    function valueOf(opt) { return opt !== null && typeof opt === "object" ? opt.value : opt; }

    readonly property string currentLabel: {
        for (const o of root.options)
            if (valueOf(o) === root.value) return labelOf(o);
        return root.value !== undefined && root.value !== null && root.value !== ""
             ? String(root.value) : root.placeholder;
    }

    // The closed control.
    BrixCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        radius: Theme.radiusXs
        color: root.enabled ? Theme.surfaceAlt : Theme.surfaceDeep
        shadowOffset: 0
        borderColor: root.open ? Theme.primary : Theme.outline

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXs
            anchors.rightMargin: Theme.spaceXs
            spacing: Theme.spaceXs

            Text {
                Layout.fillWidth: true
                text: root.currentLabel
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: root.enabled ? Theme.foreground : Theme.foregroundDim
            }

            Text {
                text: root.open ? "󰅃" : "󰅀"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                color: Theme.foregroundDim
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = !root.open
        }
    }

    // The open list.
    BrixCard {
        Layout.fillWidth: true
        visible: root.open && root.options.length > 0
        Layout.preferredHeight: Math.min(root.maxListHeight, list.contentHeight + 4)
        radius: Theme.radiusXs
        color: Theme.surfaceDeep
        shadowOffset: 0

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 2
            clip: true
            model: root.options
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 22
                radius: Theme.radiusXs
                color: root.valueOf(modelData) === root.value ? Theme.primary
                     : hover.hovered ? Theme.surfaceAlt : "transparent"

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceXs
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceXs
                    text: root.labelOf(parent.modelData)
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightBold
                    color: root.valueOf(parent.modelData) === root.value
                           ? Theme.textOn(Theme.primary) : Theme.foreground
                }

                HoverHandler { id: hover }

                TapHandler {
                    onTapped: {
                        root.open = false;
                        root.picked(root.valueOf(parent.modelData));
                    }
                }
            }
        }
    }
}
