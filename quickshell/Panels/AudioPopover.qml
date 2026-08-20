// Output control, hanging under the speaker glyph: level, mute, and which sink
// the machine plays through.
//
// The Control Center's AudioCard covers the same ground alongside everything
// else; this is the one-click path to it. Both read the same Audio service, so
// there is no second copy of the logic to drift.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "audio"
    alignment: "topAnchor"
    // No scrim: dimming the whole screen behind a card this small is heavier
    // than what it is for, and the bar stays live underneath it.
    scrimEnabled: false
    anchorX: Panels.popoverAnchorX
    contentWidth: 300
    contentHeight: 104 + (Audio.sinks.length > 1
                         ? 20 + Math.min(Audio.sinks.length, 4) * 26 : 0)

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            SectionHeader { text: "OUTPUT"; icon: "󰕾"; Layout.fillWidth: true }

            Text {
                Layout.fillWidth: true
                text: Audio.hasSink ? Audio.sinkName : "No output device"
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
                    icon: Audio.volumeIcon
                    tooltip: Audio.muted ? "Unmute" : "Mute"
                    size: 24
                    accent: Audio.muted ? Theme.error : Theme.surface
                    onClicked: Audio.toggleMute()
                }

                BrixSlider {
                    Layout.fillWidth: true
                    enabled: Audio.hasSink
                    value: Audio.volume
                    accent: Audio.muted ? Theme.surfaceDeep : Theme.pink
                    onMoved: v => Audio.setVolume(v)
                }

                Text {
                    text: Math.round(Audio.volume * 100) + "%"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSm
                    font.weight: Theme.weightBold
                    color: Theme.foregroundDim
                }
            }

            SectionHeader {
                visible: Audio.sinks.length > 1
                text: "DEVICES"
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Repeater {
                    model: Audio.sinks.length > 1 ? Audio.sinks : []
                    delegate: DeviceRow {
                        required property var modelData
                        node: modelData
                        current: Audio.sink === modelData
                        onPicked: Audio.setDefaultSink(node)
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // One selectable device. Shared shape with MicPopover's rows — kept local to
    // each popover rather than factored out, because the two differ only in
    // which service call they make and a component taking a setter reads worse
    // than the four lines it saves.
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
