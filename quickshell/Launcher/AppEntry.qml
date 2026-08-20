// A single launcher row: themed icon, name, generic name/comment.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Theme
import qs.Components

Item {
    id: root

    property var entry: null
    property bool selected: false

    signal activated()
    signal hovered()

    implicitHeight: 46

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusSm
        shadowOffset: root.selected ? Theme.shadowSm : 0
        border.width: root.selected ? Theme.border : 0
        color: root.selected ? Theme.primary
             : mouse.containsMouse ? Theme.surfaceDeep
             : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceSm
            anchors.rightMargin: Theme.spaceSm
            spacing: Theme.spaceMd

            // Icon in its own bordered tile, matching the Neobrix shortcut tiles.
            BrixCard {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Theme.radiusXs
                shadowOffset: 0
                color: root.selected ? Theme.surface : Theme.surfaceAlt
                border.width: Theme.border

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 20
                    source: root.entry
                            ? Quickshell.iconPath(root.entry.icon, "application-x-executable")
                            : ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.entry ? root.entry.name : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMd
                    font.weight: Theme.weightBold
                    color: root.selected ? Theme.onAccent : Theme.foreground
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: {
                        if (!root.entry) return "";
                        return root.entry.genericName || root.entry.comment || "";
                    }
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    // The same ink the name above uses, at reduced opacity —
                    // rather than a literal black, which happened to suit the
                    // current accent and would have stopped suiting it the
                    // moment the palette moved.
                    color: root.selected
                           ? Qt.rgba(Theme.onAccent.r, Theme.onAccent.g,
                                     Theme.onAccent.b, 0.55)
                           : Theme.foregroundDim
                }
            }

            Text {
                visible: root.selected
                text: "⏎"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMd
                font.weight: Theme.weightBold
                color: Theme.onAccent
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Movement, not entry. While the arrows drive the list, rows scroll
        // under a stationary pointer, and each one entering it fired `hovered`,
        // which pulled the selection back to whatever was under the mouse. The
        // keyboard then moved it on again, so the highlight flipped between two
        // rows several times a second — a strobe between the accent and the
        // background, for as long as a key was held.
        //
        // Requiring the pointer to actually move means hover follows the mouse
        // rather than the list moving beneath it.
        onPositionChanged: root.hovered()
        onClicked: root.activated()
    }
}
