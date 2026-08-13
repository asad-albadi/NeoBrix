// Focused window: application icon plus elided title.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    property int maxWidth: 260

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string appClass: {
        if (!toplevel || !toplevel.lastIpcObject) return "";
        return toplevel.lastIpcObject.class || "";
    }
    readonly property string title: toplevel && toplevel.title ? toplevel.title : ""
    readonly property bool hasWindow: toplevel !== null && title !== ""

    readonly property var entry: appClass !== "" ? DesktopEntries.heuristicLookup(appClass) : null
    readonly property string iconName: entry && entry.icon ? entry.icon : appClass.toLowerCase()

    implicitWidth: Math.min(maxWidth, row.implicitWidth)
    implicitHeight: Theme.barIslandHeight - Theme.spaceSm
    clip: true

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceSm

        IconImage {
            visible: root.hasWindow && source !== ""
            implicitSize: 17
            source: Quickshell.iconPath(root.iconName, true)
        }

        Text {
            Layout.maximumWidth: root.maxWidth - 24
            text: root.hasWindow ? root.title : "Desktop"
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMd
            font.weight: Theme.weightBold
            color: root.hasWindow ? Theme.foreground : Theme.foregroundDim
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.hasWindow ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mev => {
            if (!root.hasWindow) return;
            if (mev.button === Qt.MiddleButton)
                Hypr.closeWindow(root.toplevel.address);
            else
                Hypr.focusWindow(root.toplevel.address);
        }
    }
}
