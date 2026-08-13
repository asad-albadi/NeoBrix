// Notification bell with unread badge. Opens the notification centre.

import QtQuick
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    implicitWidth: 22
    implicitHeight: 22

    Text {
        anchors.centerIn: parent
        text: Notifs.doNotDisturb ? "󰂛" : (Notifs.hasUnread ? "󱅫" : "󰂚")
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontLg
        color: Notifs.doNotDisturb ? Theme.foregroundDim
             : Notifs.hasUnread ? Theme.foreground : Theme.foreground
        opacity: mouse.containsMouse ? 0.65 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
    }

    // Unread count badge.
    BrixCard {
        visible: Notifs.unreadCount > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -3
        anchors.topMargin: -3
        width: Math.max(13, badge.implicitWidth + 5)
        height: 13
        radius: Theme.radiusPill
        color: Theme.error
        shadowOffset: 0

        Text {
            id: badge
            anchors.centerIn: parent
            text: Notifs.unreadCount > 9 ? "9+" : Notifs.unreadCount
            font.family: Theme.fontFamily
            font.pixelSize: 8
            font.weight: Theme.weightHeavy
            color: Theme.onAccent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mev => {
            if (mev.button === Qt.RightButton) {
                Notifs.doNotDisturb = !Notifs.doNotDisturb;
            } else if (mev.button === Qt.MiddleButton) {
                Notifs.clearHistory();
            } else {
                Panels.toggleControl("notifications");
                Notifs.markAllRead();
            }
        }
    }

    BrixTooltip {
        text: Notifs.doNotDisturb
              ? "Do not disturb  ·  right-click to resume"
              : (Notifs.count > 0
                 ? Notifs.count + " notification" + (Notifs.count === 1 ? "" : "s")
                   + "  ·  middle-click clears"
                 : "No notifications")
        visible: mouse.containsMouse
        anchorItem: root
    }
}
