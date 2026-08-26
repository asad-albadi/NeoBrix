// Still-frame previews for one workspace. The capture source exists only while
// this popup is visible, so merely having windows open costs no screencopy work.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.Theme
import qs.Components

PopupWindow {
    id: root

    property Item anchorTarget: null
    property var windows: []
    property int workspaceId: 0
    property bool triggerHovered: false
    readonly property bool popupHovered: hover.hovered

    signal windowChosen(var toplevel)

    function appClass(toplevel) {
        if (!toplevel) return "";
        const wl = toplevel.wayland;
        if (wl && wl.appId) return wl.appId;
        const ipc = toplevel.lastIpcObject;
        return ipc && ipc.class ? ipc.class : "";
    }

    function iconFor(toplevel) {
        const cls = appClass(toplevel);
        if (!cls) return Quickshell.iconPath("application-x-executable");
        const entry = DesktopEntries.heuristicLookup(cls);
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : cls,
                                   "application-x-executable");
    }

    function reconsider() {
        if (triggerHovered || popupHovered) {
            hideTimer.stop();
            if (!visible && !showTimer.running) showTimer.restart();
        } else {
            showTimer.stop();
            if (visible) hideTimer.restart();
        }
    }

    onTriggerHoveredChanged: reconsider()
    onPopupHoveredChanged: reconsider()
    onWindowsChanged: if (windows.length === 0) visible = false

    Timer {
        id: showTimer
        interval: 220
        onTriggered: if (root.triggerHovered && root.windows.length > 0) root.visible = true
    }

    // Covers the small pointer journey from the bar chip into the popup without
    // leaving a sticky preview behind when the pointer goes somewhere else.
    Timer {
        id: hideTimer
        interval: 140
        onTriggered: if (!root.triggerHovered && !root.popupHovered) root.visible = false
    }

    readonly property int columns: Math.min(3, Math.max(1, windows.length))
    readonly property int rows: Math.ceil(windows.length / columns)
    readonly property int tileWidth: 220
    readonly property int tileHeight: 156

    visible: false
    color: "transparent"
    anchor.item: anchorTarget
    anchor.rect.x: anchorTarget ? Math.round(anchorTarget.width / 2 - implicitWidth / 2) : 0
    anchor.rect.y: anchorTarget ? anchorTarget.height + Theme.spaceMd : 0
    anchor.adjustment: PopupAdjustment.SlideX
    implicitWidth: columns * tileWidth + (columns - 1) * Theme.spaceSm
                   + Theme.spaceMd * 2 + Theme.shadowMd
    implicitHeight: rows * tileHeight + (rows - 1) * Theme.spaceSm
                    + Theme.spaceMd * 2 + Theme.shadowMd

    BrixCard {
        width: root.implicitWidth - Theme.shadowMd
        height: root.implicitHeight - Theme.shadowMd
        radius: Theme.radiusMd
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        GridLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            columns: root.columns
            rowSpacing: Theme.spaceSm
            columnSpacing: Theme.spaceSm

            Repeater {
                model: root.windows

                delegate: BrixCard {
                    id: tile
                    required property var modelData

                    Layout.preferredWidth: root.tileWidth
                    Layout.preferredHeight: root.tileHeight
                    radius: Theme.radiusSm
                    shadowOffset: 0
                    border.width: tileMouse.containsMouse ? Theme.borderThick : Theme.border
                    color: tileMouse.containsMouse ? Theme.surface : Theme.surfaceDeep

                    Item {
                        anchors.fill: parent
                        anchors.margins: Theme.borderThick
                        clip: true

                        Rectangle {
                            id: frame
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 120
                            color: Theme.background

                            ScreencopyView {
                                id: capture
                                anchors.fill: parent
                                captureSource: root.visible && tile.modelData
                                               ? tile.modelData.wayland : null
                                live: false
                                paintCursor: false
                                constraintSize: Qt.size(frame.width, frame.height)
                            }

                            Column {
                                visible: !capture.hasContent
                                anchors.centerIn: parent
                                spacing: Theme.spaceXs

                                IconImage {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    implicitSize: 30
                                    source: root.iconFor(tile.modelData)
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "CAPTURING"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontXs
                                    font.weight: Theme.weightBold
                                    color: Theme.foregroundDim
                                }
                            }
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 30
                            spacing: Theme.spaceXs

                            IconImage {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                source: root.iconFor(tile.modelData)
                            }

                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData && tile.modelData.title
                                      ? tile.modelData.title : root.appClass(tile.modelData)
                                elide: Text.ElideRight
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontXs
                                font.weight: Theme.weightBold
                                color: Theme.foreground
                            }
                        }
                    }

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.visible = false;
                            root.windowChosen(tile.modelData);
                        }
                    }
                }
            }
        }
    }

    // This area also owns the gaps between tiles, keeping the popup open while
    // the pointer moves through its content.
    HoverHandler {
        id: hover
    }
}
