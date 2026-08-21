// Clipboard history, backed by cliphist. Type to filter, Enter to put the
// selected entry back on the clipboard.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "clipboard"
    alignment: "center"
    contentWidth: 560
    contentHeight: 420

    onPanelOpened: { filter.text = ""; list.currentIndex = 0; Clip.refresh(); filter.forceActiveFocus(); }

    readonly property var results: {
        const q = filter.text.toLowerCase();
        if (q === "") return Clip.entries;
        return Clip.entries.filter(e => e.preview.toLowerCase().indexOf(q) !== -1);
    }

    function useCurrent() {
        if (root.results.length === 0) return;
        const idx = Math.max(0, Math.min(root.results.length - 1, list.currentIndex));
        Clip.copy(root.results[idx]);
        Panels.close();
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

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                Text {
                    text: "󰆏  CLIPBOARD"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightHeavy
                    font.letterSpacing: 1
                    color: Theme.foreground
                }
                Item { Layout.fillWidth: true }
                BrixChip {
                    text: root.results.length + " entries"
                    accent: Theme.tertiary
                }
                BrixButton {
                    text: "WIPE"
                    icon: "󰩹"
                    fontSize: Theme.fontXs
                    accent: Theme.error
                    enabled: Clip.entries.length > 0
                    onClicked: Clip.wipe()
                }
            }

            BrixCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceMd
                    anchors.rightMargin: Theme.spaceMd
                    spacing: Theme.spaceSm

                    Text {
                        text: "󰍉"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMd
                        color: Theme.foregroundDim
                    }

                    TextInput {
                        id: filter
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMd
                        font.weight: Theme.weightBold
                        color: Theme.foreground
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onAccent
                        clip: true
                        focus: true

                        Text {
                            visible: filter.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Filter history…"
                            font: filter.font
                            color: Theme.foregroundDim
                        }

                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onPressed: ev => {
                            if (ev.key === Qt.Key_Escape) {
                                Panels.close();
                                ev.accepted = true;
                            } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                root.useCurrent();
                                ev.accepted = true;
                            }
                        }
                        onTextChanged: list.currentIndex = 0
                    }
                }
            }

            BrixCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm
                clip: true

                ListView {
                    id: list
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    model: root.results
                    spacing: Theme.spaceXs
                    clip: true
                    currentIndex: 0
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: clipRow
                        required property var modelData
                        required property int index
                        width: ListView.view.width - Theme.spaceSm
                        height: 34

                        BrixCard {
                            anchors.fill: parent
                            radius: Theme.radiusXs
                            shadowOffset: clipRow.index === list.currentIndex ? Theme.shadowSm : 0
                            border.width: clipRow.index === list.currentIndex ? Theme.border : 0
                            color: clipRow.index === list.currentIndex ? Theme.primary
                                 : clipMouse.containsMouse ? Theme.surfaceDeep
                                 : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.spaceSm
                                anchors.rightMargin: Theme.spaceXs
                                spacing: Theme.spaceSm

                                Text {
                                    text: clipRow.modelData.isImage ? "󰋩" : "󰈙"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontMd
                                    color: clipRow.index === list.currentIndex
                                           ? Theme.onAccent : Theme.foregroundDim
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: clipRow.modelData.preview
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSm
                                    color: clipRow.index === list.currentIndex
                                           ? Theme.onAccent : Theme.foreground
                                }

                                BrixIconButton {
                                    icon: "󰅖"
                                    size: 18
                                    radius: Theme.radiusXs
                                    shadowOffset: 0
                                    accent: "transparent"
                                    iconColor: clipRow.index === list.currentIndex
                                               ? Theme.onAccent : Theme.foregroundDim
                                    onClicked: Clip.remove(clipRow.modelData)
                                }
                            }
                        }

                        MouseArea {
                            id: clipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: list.currentIndex = clipRow.index
                            onClicked: { list.currentIndex = clipRow.index; root.useCurrent(); }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.results.length === 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Clip.loading ? "󰔟" : "󰅖"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontXl + 6
                            color: Theme.foregroundDim
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: Clip.loading ? "loading…" : "clipboard history is empty"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.weightBold
                            color: Theme.foregroundDim
                        }
                    }
                }
            }
        }
    }
}
