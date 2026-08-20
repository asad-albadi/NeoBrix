// Input control, hanging under the microphone glyph: level, mute, and which
// source the machine records from.
//
// The mirror of AudioPopover. Muting here is the one control in the shell worth
// reaching in a hurry, which is the argument for it having its own glyph rather
// than living two clicks deep in the Control Center.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "mic"
    alignment: "topAnchor"
    // No scrim: dimming the whole screen behind a card this small is heavier
    // than what it is for, and the bar stays live underneath it.
    scrimEnabled: false
    anchorX: Panels.popoverAnchorX
    contentWidth: 300
    contentHeight: 104 + (Audio.sources.length > 1
                         ? 20 + Math.min(Audio.sources.length, 4) * 26 : 0)

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            SectionHeader { text: "INPUT"; icon: "󰍬"; Layout.fillWidth: true }

            Text {
                Layout.fillWidth: true
                text: Audio.hasSource ? Audio.sourceName : "No input device"
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                font.weight: Theme.weightBold
                color: Theme.foreground
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                BrixIconButton {
                    icon: Audio.micIcon
                    tooltip: Audio.micMuted ? "Unmute" : "Mute"
                    size: 24
                    accent: Audio.micMuted ? Theme.error : Theme.surface
                    onClicked: Audio.toggleMicMute()
                }

                BrixSlider {
                    Layout.fillWidth: true
                    enabled: Audio.hasSource
                    value: Audio.micVolume
                    accent: Audio.micMuted ? Theme.surfaceDeep : Theme.secondary
                    onMoved: v => Audio.setMicVolume(v)
                }

                Text {
                    text: Math.round(Audio.micVolume * 100) + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSm
                    font.weight: Theme.weightBold
                    color: Theme.foregroundDim
                }
            }

            SectionHeader {
                visible: Audio.sources.length > 1
                text: "DEVICES"
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: Audio.sources.length > 1 ? Audio.sources : []
                    delegate: DeviceRow {
                        required property var modelData
                        node: modelData
                        current: Audio.source === modelData
                        onPicked: Audio.setDefaultSource(node)
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // One selectable device; the mirror of AudioPopover's row.
    component DeviceRow: Item {
        id: rowRoot
        property var node: null
        property bool current: false
        signal picked()

        Layout.fillWidth: true
        implicitHeight: 24

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusXs
            color: rowRoot.current ? Theme.secondary
                 : rowMouse.containsMouse ? Theme.surfaceDeep : "transparent"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXs
            anchors.rightMargin: Theme.spaceXs
            spacing: Theme.spaceXs

            Text {
                Layout.fillWidth: true
                text: rowRoot.node
                      ? (rowRoot.node.nickname || rowRoot.node.description || rowRoot.node.name)
                      : ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 9
                color: rowRoot.current ? Theme.textOn(Theme.secondary) : Theme.foreground
            }
            Text {
                visible: rowRoot.current
                text: "󰄬"
                font.family: Theme.fontFamily
                font.pixelSize: 10
                color: Theme.textOn(Theme.secondary)
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rowRoot.picked()
        }
    }
}
