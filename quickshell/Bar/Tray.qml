// StatusNotifierItem tray. Menus are rendered with the shell's own components
// (via QsMenuOpener) rather than a native Qt menu, so they match the rest of the
// design system.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Theme
import qs.Components

Item {
    id: root

    readonly property var items: SystemTray.items ? SystemTray.items.values : []
    // Collapses to zero width when nothing is in the tray, so the bar does not
    // carry an empty gap.
    readonly property bool hasItems: items.length > 0

    visible: hasItems
    implicitWidth: hasItems ? row.implicitWidth : 0
    implicitHeight: Theme.barIslandHeight - Theme.spaceSm

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceXs

        Repeater {
            model: root.items

            delegate: Item {
                id: entry
                required property var modelData

                implicitWidth: 18
                implicitHeight: 18

                IconImage {
                    id: img
                    anchors.centerIn: parent
                    implicitSize: 14
                    source: entry.modelData.icon
                    opacity: mouse.containsMouse ? 0.7 : 1
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mev => {
                        const item = entry.modelData;
                        if (mev.button === Qt.RightButton || item.onlyMenu) {
                            if (item.hasMenu) menu.openAt(entry, item);
                        } else if (mev.button === Qt.MiddleButton) {
                            item.secondaryActivate();
                        } else {
                            item.activate();
                        }
                    }
                }

                BrixTooltip {
                    text: entry.modelData.tooltipTitle !== ""
                          ? entry.modelData.tooltipTitle
                          : entry.modelData.title
                    visible: mouse.containsMouse && text !== ""
                    anchorItem: entry
                }
            }
        }
    }

    TrayMenu { id: menu }
}
