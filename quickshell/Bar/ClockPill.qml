// Clock chip. Opens the calendar panel.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    implicitWidth: pill.width
    implicitHeight: Theme.barIslandHeight - Theme.spaceSm
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Qt's "h" only means 1-12 when AP is part of the same format string, and the
    // meridiem is rendered as a separate chip here, so derive both explicitly.
    readonly property string timeText: {
        const h = clock.hours % 12;
        const m = clock.minutes;
        return (h === 0 ? 12 : h) + ":" + (m < 10 ? "0" : "") + m;
    }
    readonly property string meridiem: clock.hours < 12 ? "AM" : "PM"

    BrixCard {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        height: parent.implicitHeight
        width: pillRow.implicitWidth + Theme.spaceMd
        radius: Theme.radiusPill
        color: Panels.isOpen("calendar") ? Theme.primary : Theme.tertiary
        // Flat inside the island; press feedback is the colour change alone.
        shadowOffset: 0
        Behavior on color { ColorAnimation { duration: Theme.durFast } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: Theme.spaceXs

            Text {
                text: "󰥔"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                color: Theme.onAccent
            }
            Text {
                text: root.timeText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMd
                font.weight: Theme.weightHeavy
                color: Theme.onAccent
            }
            // Small inset badge for AM/PM, as on the reference clock chip.
            BrixCard {
                Layout.preferredWidth: meridiem.implicitWidth + Theme.spaceXs
                Layout.preferredHeight: meridiem.implicitHeight + 2
                radius: Theme.radiusXs
                shadowOffset: 0
                border.width: 0
                color: Qt.darker(Panels.isOpen("calendar") ? Theme.primary : Theme.tertiary, 1.12)

                Text {
                    id: meridiem
                    anchors.centerIn: parent
                    text: root.meridiem
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.weight: Theme.weightHeavy
                    color: Theme.onAccent
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("calendar")
    }

    BrixTooltip {
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
        visible: mouse.containsMouse && !Panels.isOpen("calendar")
        anchorItem: root
    }
}
