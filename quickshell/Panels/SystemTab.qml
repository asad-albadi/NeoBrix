// The dashboard grid: identity · clock · levels · specs · media · resources ·
// quick actions. Network and Bluetooth live in the CONNECTIVITY tab.
//
// Laid out in three columns like the Neobrix reference, with the media and
// resource cards spanning the bottom.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    property bool active: false

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spaceMd

        // ── column 1: identity + quick actions ──────────────────────────────
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 190
            Layout.minimumWidth: 190
            Layout.maximumWidth: 190
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            BrixCard {
                Layout.fillWidth: true
                // Sized to its contents rather than a fixed 132: a full name
                // long enough to wrap would otherwise run out of the card.
                Layout.preferredHeight: idCol.implicitHeight + Theme.spaceMd * 2
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                ColumnLayout {
                    id: idCol
                    anchors.centerIn: parent
                    width: parent.width - Theme.spaceMd * 2
                    spacing: Theme.spaceXs

                    BrixCard {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        radius: Theme.radiusSm
                        color: Theme.primary
                        shadowOffset: Theme.shadowSm

                        Text {
                            anchors.centerIn: parent
                            text: SysInfo.displayName.length > 0
                                  ? SysInfo.displayName.charAt(0).toUpperCase() : "?"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXl + 4
                            font.weight: Theme.weightHeavy
                            color: Theme.onAccent
                        }
                    }

                    // The account's real name, with the username left to the
                    // user@host line below where it belongs — printing the login
                    // name twice, large and then small, said nothing the second
                    // time. Falls back to the username when GECOS is empty.
                    Text {
                        Layout.fillWidth: true
                        // Wraps rather than elides: a name is not much use with
                        // its end cut off, and there is room downwards.
                        text: SysInfo.displayName
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLg
                        font.weight: Theme.weightHeavy
                        color: Theme.foreground
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: SysInfo.username + "@" + SysInfo.hostname
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        color: Theme.foregroundDim
                    }

                    BrixChip {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.spaceXs
                        icon: "󰄯"
                        text: "Online"
                        accent: Net.online ? Theme.secondary : Theme.surfaceDeep
                    }
                }
            }

            // Quick actions — the tile strip from the reference, wired to real
            // shell functions instead of bookmarks.
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

                    SectionHeader { text: "QUICK ACTIONS"; Layout.fillWidth: true }

                    ActionRow {
                        Layout.fillWidth: true
                        icon: "󰆏"; label: "Clipboard"; accent: Theme.tertiary
                        onActivated: Panels.open("clipboard")
                    }
                    ActionRow {
                        Layout.fillWidth: true
                        icon: "󰹑"; label: "Screenshot"; accent: Theme.info
                        onActivated: {
                            Panels.close();
                            Quickshell.execDetached(["neobrix-screenshot", "region"]);
                        }
                    }
                    ActionRow {
                        Layout.fillWidth: true
                        icon: "󰸉"; label: "Wallpaper"; accent: Theme.pink
                        onActivated: Quickshell.execDetached(["neobrix-wallpaper", "next"])
                    }
                    ActionRow {
                        Layout.fillWidth: true
                        icon: "󰌾"; label: "Lock"; accent: Theme.warning
                        onActivated: { Panels.close(); Session.lock(); }
                    }
                    ActionRow {
                        Layout.fillWidth: true
                        icon: "󰜉"; label: "Reload shell"; accent: Theme.warning
                        onActivated: Quickshell.reload(true)
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ── column 2: clock + levels + media ────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: false
                Layout.preferredHeight: 74
                spacing: Theme.spaceMd

                // Clock card.
                BrixCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMd
                    color: Theme.surface
                    shadowOffset: Theme.shadowSm

                    SystemClock {
                        id: clock
                        precision: SystemClock.Seconds
                        enabled: root.active
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceMd
                        spacing: Theme.spaceMd

                        Text {
                            text: {
                                const h = clock.hours % 12;
                                const m = clock.minutes;
                                return (h === 0 ? 12 : h) + " : " + (m < 10 ? "0" : "") + m;
                            }
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontDisplay
                            font.weight: Theme.weightHeavy
                            color: Theme.foreground
                        }

                        Text {
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: Theme.spaceSm
                            text: clock.hours < 12 ? "AM" : "PM"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.weightBold
                            color: Theme.foregroundDim
                        }

                        Rectangle {
                            Layout.preferredWidth: Theme.border
                            Layout.fillHeight: true
                            Layout.topMargin: Theme.spaceXs
                            Layout.bottomMargin: Theme.spaceXs
                            color: Theme.outline
                            opacity: 0.3
                        }

                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase()
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                                font.weight: Theme.weightHeavy
                                color: Theme.foreground
                            }
                            Text {
                                text: Qt.formatDateTime(clock.date, "MMMM d, yyyy")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSm
                                color: Theme.foregroundDim
                            }
                            Text {
                                text: "UP " + SysInfo.uptimeText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                                font.weight: Theme.weightBold
                                color: Theme.foregroundDim
                            }
                        }

                        Item { Layout.fillWidth: true }

                        BrixIconButton {
                            icon: "󰃭"
                            accent: Theme.tertiary
                            iconColor: Theme.onAccent
                            tooltip: "Calendar"
                            onClicked: { Panels.close(); Panels.open("calendar"); }
                        }
                    }
                }

            }

            // Audio card — output level, microphone level and output device
            // selection, all straight from PipeWire.
            AudioCard {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            // Media card.
            MediaCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }

        // ── column 3: specs + resources ─────────────────────────────────────
        // Connectivity used to sit under these two and take the slack with
        // fillHeight. With it promoted to its own tab, the two remaining cards
        // share that space instead of leaving a hole at the bottom of the
        // column: both stretch, and inside them the spec tiles and the meters
        // stretch too, so the extra height goes into the rows rather than into
        // an empty strip under the last one.
        ColumnLayout {
            Layout.fillWidth: false
            Layout.preferredWidth: 250
            Layout.minimumWidth: 250
            Layout.maximumWidth: 250
            Layout.fillHeight: true
            spacing: Theme.spaceMd

            SpecsCard { Layout.fillWidth: true; Layout.fillHeight: true }
            ResourcesCard { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }

    // ── local helper components ─────────────────────────────────────────────
    component ActionRow: Item {
        id: actionRoot
        property string icon: ""
        property string label: ""
        property color accent: Theme.primary
        signal activated()

        implicitHeight: 28

        BrixCard {
            anchors.fill: parent
            radius: Theme.radiusXs
            shadowOffset: 0
            border.width: actionMouse.containsMouse ? Theme.border : 0
            color: actionMouse.containsMouse ? Theme.surfaceDeep : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceXs
                anchors.rightMargin: Theme.spaceSm
                spacing: Theme.spaceSm

                BrixCard {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: Theme.radiusXs
                    shadowOffset: 0
                    color: actionRoot.accent

                    Text {
                        anchors.centerIn: parent
                        text: actionRoot.icon
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSm
                        color: Theme.textOn(actionRoot.accent)
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: actionRoot.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSm
                    font.weight: Theme.weightBold
                    color: Theme.foreground
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: actionRoot.activated()
        }
    }

}
