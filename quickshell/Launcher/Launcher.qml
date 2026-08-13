// ─────────────────────────────────────────────────────────────────────────────
//  Application launcher.
//
//  Search over the XDG desktop entry index, keyboard-first (arrows/Tab to move,
//  Enter to launch, Escape to close) with full mouse support. The list is a
//  ListView so a thousand entries cost the same as ten.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "launcher"
    onPanelClosed: list.currentIndex = 0
    onPanelOpened: { list.currentIndex = 0; input.forceActiveFocus(); }

    alignment: "center"
    contentWidth: 560
    contentHeight: 460

    onOpenChanged: if (open) input.text = ""
    readonly property var results: Apps.search(input.text)

    function launchCurrent() {
        if (root.results.length === 0) return;
        const idx = Math.max(0, Math.min(root.results.length - 1, list.currentIndex));
        Apps.launch(root.results[idx]);
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

            // ── search field ────────────────────────────────────────────────
            BrixCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusMd
                color: Theme.surface
                shadowOffset: Theme.shadowSm

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceMd
                    anchors.rightMargin: Theme.spaceSm
                    spacing: Theme.spaceSm

                    Text {
                        text: "󰍉"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLg
                        color: Theme.foregroundDim
                    }

                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLg
                        font.weight: Theme.weightBold
                        color: Theme.foreground
                        selectionColor: Theme.primary
                        selectedTextColor: Theme.onAccent
                        clip: true
                        focus: true
                        activeFocusOnTab: true

                        Text {
                            visible: input.text === ""
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Search applications…"
                            font: input.font
                            color: Theme.foregroundDim
                        }

                        Keys.onDownPressed: list.incrementCurrentIndex()
                        Keys.onUpPressed: list.decrementCurrentIndex()
                        Keys.onPressed: ev => {
                            if (ev.key === Qt.Key_Escape) {
                                Panels.close();
                                ev.accepted = true;
                            } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                root.launchCurrent();
                                ev.accepted = true;
                            } else if (ev.key === Qt.Key_Tab) {
                                list.incrementCurrentIndex();
                                ev.accepted = true;
                            } else if (ev.key === Qt.Key_Backtab) {
                                list.decrementCurrentIndex();
                                ev.accepted = true;
                            }
                        }

                        onTextChanged: list.currentIndex = 0
                    }

                    BrixChip {
                        visible: root.results.length > 0
                        text: root.results.length
                        accent: Theme.tertiary
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // ── results ─────────────────────────────────────────────────────
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
                    highlightMoveDuration: Theme.durFast
                    keyNavigationWraps: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: AppEntry {
                        required property var modelData
                        required property int index

                        width: list.width - Theme.spaceSm
                        entry: modelData
                        selected: list.currentIndex === index
                        onActivated: {
                            list.currentIndex = index;
                            root.launchCurrent();
                        }
                        onHovered: list.currentIndex = index
                    }

                    Text {
                        visible: root.results.length === 0
                        anchors.centerIn: parent
                        text: "󰦤   no matches"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLg
                        font.weight: Theme.weightBold
                        color: Theme.foregroundDim
                    }
                }
            }

            // ── hint row ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceMd

                Text {
                    text: "↑↓ select    ⏎ launch    esc close"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    color: Theme.foregroundDim
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: Apps.all.length + " apps"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    color: Theme.foregroundDim
                }
            }
        }
    }
}
