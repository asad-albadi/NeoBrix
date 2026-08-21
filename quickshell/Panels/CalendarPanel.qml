// Clock + calendar dropdown, anchored under the bar's clock chip.
//
// The month grid is computed here rather than using QtQuick.Controls' MonthGrid
// so the cells can be styled as brutalist chips.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "calendar"
    alignment: "topRight"
    contentWidth: 324
    contentHeight: 384

    onPanelOpened: { monthOffset = 0; SysInfo.subscribe(); }
    onPanelClosed: SysInfo.unsubscribe()

    property int monthOffset: 0

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
        enabled: root.open
    }

    readonly property date today: clock.date
    readonly property date shown: {
        const d = new Date(today.getFullYear(), today.getMonth() + monthOffset, 1);
        return d;
    }

    // 42 cells (6 weeks) covering the shown month plus leading/trailing days.
    readonly property var cells: {
        const first = new Date(shown.getFullYear(), shown.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - first.getDay());          // back up to Sunday
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === shown.getMonth(),
                isToday: d.getFullYear() === today.getFullYear()
                         && d.getMonth() === today.getMonth()
                         && d.getDate() === today.getDate(),
                isWeekend: d.getDay() === 0 || d.getDay() === 6
            });
        }
        return out;
    }

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowLg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceMd

            // ── time header ─────────────────────────────────────────────────
            BrixCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 84
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: -2

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.spaceSm

                        Text {
                            text: {
                                const h = clock.hours % 12;
                                const m = clock.minutes;
                                return (h === 0 ? 12 : h) + ":" + (m < 10 ? "0" : "") + m;
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontDisplay + 2
                            font.weight: Theme.weightHeavy
                            color: Theme.foreground
                        }

                        BrixChip {
                            Layout.alignment: Qt.AlignVCenter
                            text: clock.hours < 12 ? "AM" : "PM"
                            accent: Theme.tertiary
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSm
                        font.weight: Theme.weightBold
                        color: Theme.foregroundDim
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spaceXs
                        spacing: Theme.spaceXs

                        BrixChip {
                            icon: "󰅐"
                            text: "UP " + SysInfo.uptimeText
                            accent: Theme.secondary
                        }
                        BrixChip {
                            icon: "󰃭"
                            text: "W" + root.isoWeek(clock.date)
                            accent: Theme.info
                        }
                    }
                }
            }

            // ── month navigation ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(root.shown, "MMMM yyyy")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightHeavy
                    color: Theme.foreground
                }

                BrixIconButton {
                    icon: "󰅁"
                    size: 24
                    radius: Theme.radiusPill
                    accent: Theme.surface
                    onClicked: root.monthOffset--
                }
                BrixIconButton {
                    icon: "󰋜"
                    size: 24
                    radius: Theme.radiusPill
                    accent: root.monthOffset === 0 ? Theme.surface : Theme.warning
                    onClicked: root.monthOffset = 0
                }
                BrixIconButton {
                    icon: "󰅂"
                    size: 24
                    radius: Theme.radiusPill
                    accent: Theme.secondary
                    onClicked: root.monthOffset++
                }
            }

            // ── grid ────────────────────────────────────────────────────────
            BrixCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceXs

                    // Weekday header.
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 7
                        columnSpacing: 0

                        Repeater {
                            model: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
                            delegate: Text {
                                required property string modelData
                                required property int index
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                                font.weight: Theme.weightBold
                                color: (index === 0 || index === 6)
                                       ? Theme.foregroundDim : Theme.foreground
                                opacity: (index === 0 || index === 6) ? 0.7 : 1
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.border
                        color: Theme.outline
                        opacity: 0.25
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 1
                        columnSpacing: 1

                        Repeater {
                            model: root.cells

                            delegate: Item {
                                id: cell
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                BrixCard {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height, 28)
                                    height: width
                                    radius: Theme.radiusPill
                                    shadowOffset: cell.modelData.isToday ? Theme.shadowSm : 0
                                    border.width: cell.modelData.isToday ? Theme.border : 0
                                    color: cell.modelData.isToday ? Theme.secondary : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: cell.modelData.day
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSm
                                        font.weight: cell.modelData.isToday
                                                     ? Theme.weightHeavy : Theme.weightNormal
                                        color: cell.modelData.isToday ? Theme.onAccent
                                             : !cell.modelData.inMonth ? Qt.rgba(
                                                   Theme.foregroundDim.r, Theme.foregroundDim.g,
                                                   Theme.foregroundDim.b, 0.4)
                                             : cell.modelData.isWeekend ? Theme.foregroundDim
                                             : Theme.foreground
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ISO-8601 week number.
    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const dayNum = (t.getDay() + 6) % 7;              // Monday = 0
        t.setDate(t.getDate() - dayNum + 3);              // nearest Thursday
        const firstThursday = new Date(t.getFullYear(), 0, 4);
        const fDayNum = (firstThursday.getDay() + 6) % 7;
        firstThursday.setDate(firstThursday.getDate() - fDayNum + 3);
        return 1 + Math.round((t - firstThursday) / (7 * 86400000));
    }
}
