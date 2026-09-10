// A value picked from a list.
//
// The list is painted over the content below it rather than taking part in the
// surrounding layout. That keeps the label and every neighbouring control
// still while the menu is open, regardless of the fixed-height card or row in
// which this selector is used. It scrolls once the list is taller than
// maxListHeight, so a monitor advertising twenty modes still fits.

import QtQuick
import QtQuick.Layouts
import qs.Theme

Item {
    id: root

    // Either plain strings, or objects with `label` and `value`.
    property var options: []
    property var value: undefined
    property string placeholder: "—"
    property int maxListHeight: 132
    property bool enabled: true
    property bool open: false

    signal picked(var value)

    implicitHeight: closed.height
    // An open list must paint above later siblings in a ColumnLayout too.
    z: open ? 100 : 0

    function labelOf(opt) { return opt !== null && typeof opt === "object" ? opt.label : opt; }
    function valueOf(opt) { return opt !== null && typeof opt === "object" ? opt.value : opt; }

    // Numbers compare with a tolerance. A scale of 1.333333 in a list will never
    // be === the 1.3333333333 that comes back from the compositor, and an exact
    // comparison silently shows no selection at all.
    function sameValue(a, b) {
        if (typeof a === "number" && typeof b === "number") return Math.abs(a - b) < 0.001;
        return a === b;
    }

    readonly property string currentLabel: {
        for (const o of root.options)
            if (root.sameValue(valueOf(o), root.value)) return labelOf(o);
        return root.value !== undefined && root.value !== null && root.value !== ""
             ? String(root.value) : root.placeholder;
    }

    // The closed control.
    BrixCard {
        id: closed
        anchors.top: parent.top
        width: parent.width
        height: 26
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
        id: menu
        x: 0
        y: closed.height + Theme.spaceXs
        width: root.width
        visible: root.open && root.options.length > 0
        height: Math.min(root.maxListHeight, list.contentHeight + 4)
        z: 1
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
                color: root.sameValue(root.valueOf(modelData), root.value) ? Theme.primary
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
                    color: root.sameValue(root.valueOf(parent.modelData), root.value)
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
