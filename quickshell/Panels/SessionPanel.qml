// Session menu.
//
// Lock / logout / suspend are one click. Reboot and shutdown deliberately require
// a second, explicit confirmation click so they cannot be triggered by accident.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "session"
    alignment: "center"
    contentWidth: 460
    contentHeight: pending === "" ? 210 : 250
    onPanelClosed: pending = ""

    // Action awaiting confirmation ("reboot" | "shutdown" | "").
    property string pending: ""

    readonly property var actions: {
        const list = [
            { id: "lock",    label: "LOCK",    glyph: "󰌾", accent: Theme.info,      danger: false },
            // Logout is destructive in the same way reboot is — every running
            // application is killed, unsaved work included — so it confirms too.
            // Lock and suspend are reversible and do not.
            { id: "logout",  label: "LOGOUT",  glyph: "󰗽", accent: Theme.tertiary,  danger: true },
            { id: "suspend", label: "SUSPEND", glyph: "󰤄", accent: Theme.secondary, danger: false },
            { id: "reboot",  label: "REBOOT",  glyph: "󰜉", accent: Theme.warning,   danger: true },
            { id: "shutdown",label: "SHUTDOWN",glyph: "󰐥", accent: Theme.error,     danger: true }
        ];
        if (Session.canHibernate)
            list.splice(3, 0, { id: "hibernate", label: "HIBERNATE", glyph: "󰋊",
                                accent: Theme.pink, danger: true });
        return list;
    }

    function invoke(action) {
        if (action.danger && root.pending !== action.id) {
            root.pending = action.id;
            return;
        }
        Panels.close();
        switch (action.id) {
        case "lock":      Session.lock(); break;
        case "logout":    Session.logout(); break;
        case "suspend":   Session.suspend(); break;
        case "hibernate": Session.hibernate(); break;
        case "reboot":    Session.reboot(); break;
        case "shutdown":  Session.shutdown(); break;
        }
    }

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowLg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceLg
            spacing: Theme.spaceMd

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                Text {
                    text: "SESSION"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightHeavy
                    font.letterSpacing: 2
                    color: Theme.foreground
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: SysInfo.username + "@" + SysInfo.hostname
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    color: Theme.foregroundDim
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.spaceSm

                Repeater {
                    model: root.actions

                    delegate: Item {
                        id: tile
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        readonly property bool armed: root.pending === modelData.id

                        BrixCard {
                            anchors.fill: parent
                            radius: Theme.radiusMd
                            shadowOffset: tileMouse.pressed ? 0 : Theme.shadowSm
                            x: tileMouse.pressed ? Theme.shadowSm : 0
                            y: tileMouse.pressed ? Theme.shadowSm : 0
                            border.width: tile.armed ? Theme.borderThick : Theme.border
                            color: tile.armed ? tile.modelData.accent
                                 : tileMouse.containsMouse ? tile.modelData.accent
                                 : Theme.surface
                            Behavior on color { ColorAnimation { duration: Theme.durFast } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Theme.spaceXs

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tile.modelData.glyph
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXl + 4
                                    color: (tile.armed || tileMouse.containsMouse)
                                           ? Theme.onAccent : Theme.foreground
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: tile.armed ? "CONFIRM?" : tile.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 8
                                    font.weight: Theme.weightHeavy
                                    color: (tile.armed || tileMouse.containsMouse)
                                           ? Theme.onAccent : Theme.foregroundDim
                                }
                            }
                        }

                        MouseArea {
                            id: tileMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.invoke(tile.modelData)
                        }
                    }
                }
            }

            // Confirmation strip — only present once a destructive tile is armed.
            RowLayout {
                Layout.fillWidth: true
                visible: root.pending !== ""
                spacing: Theme.spaceSm

                Text {
                    Layout.fillWidth: true
                    text: "Click " + root.pending.toUpperCase() + " again to confirm."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightBold
                    color: Theme.error
                }
                BrixButton {
                    text: "CANCEL"
                    fontSize: Theme.fontXs
                    accent: Theme.surface
                    onClicked: root.pending = ""
                }
            }
        }
    }
}
