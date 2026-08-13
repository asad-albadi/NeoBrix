// Themed DBusMenu renderer for tray items.
//
// QsMenuOpener gives us the live menu tree; we draw it ourselves so tray menus
// look like the rest of the shell instead of a stock Qt popup. One level of
// submenu is supported inline (expanded in place), which covers every tray app
// in practice.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.Theme
import qs.Components

PopupWindow {
    id: root

    property var trayItem: null
    property Item anchorTarget: null
    property var expanded: ({})

    function openAt(item, tray) {
        root.anchorTarget = item;
        root.trayItem = tray;
        root.expanded = {};
        root.visible = true;
    }
    function close() {
        root.visible = false;
        root.trayItem = null;
    }

    visible: false
    anchor.item: anchorTarget
    anchor.rect.x: anchorTarget ? Math.round(anchorTarget.width / 2 - implicitWidth / 2) : 0
    anchor.rect.y: anchorTarget ? anchorTarget.height + Theme.spaceSm : 0
    anchor.adjustment: PopupAdjustment.SlideX
    implicitWidth: 220
    implicitHeight: Math.min(420, card.implicitHeight + Theme.shadowMd)
    color: "transparent"

    QsMenuOpener {
        id: opener
        menu: root.trayItem ? root.trayItem.menu : null
    }

    // Clicking anywhere else closes the menu.
    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    BrixCard {
        id: card
        width: root.implicitWidth - Theme.shadowMd
        implicitHeight: column.implicitHeight + Theme.spaceSm * 2
        height: implicitHeight
        radius: Theme.radiusSm
        color: Theme.surface
        shadowOffset: Theme.shadowMd

        Column {
            id: column
            width: parent.width - Theme.spaceSm * 2
            x: Theme.spaceSm
            y: Theme.spaceSm
            spacing: 1

            Repeater {
                model: opener.children ? opener.children.values : []

                delegate: Column {
                    id: entryCol
                    required property var modelData
                    width: column.width

                    Rectangle {
                        visible: entryCol.modelData.isSeparator
                        width: parent.width
                        height: visible ? Theme.border : 0
                        color: Theme.outline
                        opacity: 0.5
                    }

                    Rectangle {
                        visible: !entryCol.modelData.isSeparator
                        width: parent.width
                        height: visible ? 24 : 0
                        radius: Theme.radiusXs
                        color: itemMouse.containsMouse ? Theme.primary : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceSm
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spaceSm

                            Text {
                                visible: entryCol.modelData.buttonType !== QsMenuButtonType.None
                                text: entryCol.modelData.checkState === Qt.Checked ? "󰄬" : " "
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSm
                                color: Theme.foreground
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            IconImage {
                                visible: entryCol.modelData.icon !== ""
                                implicitSize: 14
                                source: entryCol.modelData.icon
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: entryCol.modelData.text
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSm
                                font.weight: Theme.weightBold
                                color: entryCol.modelData.enabled ? Theme.foreground : Theme.foregroundDim
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width - 40)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            visible: entryCol.modelData.hasChildren
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.expanded[entryCol.modelData.text] ? "󰅀" : "󰅂"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            color: Theme.foregroundDim
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entryCol.modelData.enabled
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entryCol.modelData.hasChildren) {
                                    const e = Object.assign({}, root.expanded);
                                    e[entryCol.modelData.text] = !e[entryCol.modelData.text];
                                    root.expanded = e;
                                } else {
                                    entryCol.modelData.triggered();
                                    root.close();
                                }
                            }
                        }
                    }

                    // Inline submenu.
                    Column {
                        visible: entryCol.modelData.hasChildren
                                 && root.expanded[entryCol.modelData.text] === true
                        width: parent.width
                        spacing: 1

                        QsMenuOpener {
                            id: subOpener
                            menu: entryCol.modelData
                        }

                        Repeater {
                            model: subOpener.children ? subOpener.children.values : []

                            delegate: Rectangle {
                                id: subEntry
                                required property var modelData
                                width: entryCol.width
                                height: modelData.isSeparator ? Theme.border : 22
                                radius: Theme.radiusXs
                                color: modelData.isSeparator ? Theme.outline
                                     : subMouse.containsMouse ? Theme.secondary : "transparent"

                                Text {
                                    visible: !subEntry.modelData.isSeparator
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spaceLg
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: subEntry.modelData.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXs
                                    font.weight: Theme.weightBold
                                    color: Theme.foreground
                                    elide: Text.ElideRight
                                    width: Math.min(implicitWidth, parent.width - Theme.spaceXl)
                                }

                                MouseArea {
                                    id: subMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !subEntry.modelData.isSeparator && subEntry.modelData.enabled
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { subEntry.modelData.triggered(); root.close(); }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
