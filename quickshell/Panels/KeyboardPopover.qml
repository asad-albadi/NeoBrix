// Layout selection uses the same anchored card and selected rows as audio.
import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    panel: "keyboard"
    alignment: "topAnchor"
    scrimEnabled: false
    anchorX: Panels.popoverAnchorX
    contentWidth: 300
    contentHeight: column.implicitHeight + Theme.spaceMd * 2

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            SectionHeader { text: "KEYBOARD LAYOUT"; icon: "󰌌"; Layout.fillWidth: true }

            Repeater {
                model: Keyboard.layouts
                delegate: Item {
                    id: layoutRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: Theme.fontMd + Theme.spaceSm * 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusXs
                        color: layoutRow.modelData.current ? Theme.secondary
                             : rowMouse.containsMouse ? Theme.surfaceDeep : "transparent"
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceXs
                        anchors.rightMargin: Theme.spaceXs
                        spacing: Theme.spaceSm

                        Text {
                            text: layoutRow.modelData.label
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXs
                            font.weight: Theme.weightBold
                            color: layoutRow.modelData.current
                                   ? Theme.textOn(Theme.secondary) : Theme.foregroundDim
                        }
                        Text {
                            Layout.fillWidth: true
                            text: layoutRow.modelData.name
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSm
                            color: layoutRow.modelData.current
                                   ? Theme.textOn(Theme.secondary) : Theme.foreground
                        }
                        Text {
                            visible: layoutRow.modelData.current
                            text: "󰄬"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSm
                            color: Theme.textOn(Theme.secondary)
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: Keyboard.canSwitch
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Keyboard.selectLayout(layoutRow.modelData.index)
                    }
                }
            }
        }
    }
}
