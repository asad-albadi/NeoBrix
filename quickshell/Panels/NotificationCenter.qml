// Notification history with per-item dismiss, clear-all and a do-not-disturb
// switch. Shares NotificationItem with the toast layer.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services
import qs.Notifications

Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Text {
                text: Notifs.count > 0
                      ? Notifs.count + (Notifs.count === 1 ? " notification" : " notifications")
                      : "No notifications"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontMd
                font.weight: Theme.weightHeavy
                color: Theme.foreground
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "DO NOT DISTURB"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
            }
            BrixToggle {
                checked: Notifs.doNotDisturb
                accent: Theme.warning
                onToggled: on => Notifs.doNotDisturb = on
            }

            BrixButton {
                text: "CLEAR ALL"
                icon: "󰎟"
                fontSize: Theme.fontXs
                accent: Theme.surface
                enabled: Notifs.count > 0
                onClicked: Notifs.clearHistory()
            }
        }

        BrixCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.radiusMd
            color: Theme.surfaceDeep
            shadowOffset: Theme.shadowSm
            clip: true

            ListView {
                anchors.fill: parent
                anchors.margins: Theme.spaceSm
                model: Notifs.history
                spacing: Theme.spaceSm
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: NotificationItem {
                    required property var modelData
                    width: ListView.view.width - Theme.shadowSm
                    wrapper: modelData
                    popup: false
                    onDismissed: Notifs.removeFromHistory(modelData)
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: Notifs.count === 0
                spacing: Theme.spaceXs

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂚"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXl + 10
                    color: Theme.foregroundDim
                    opacity: 0.6
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "all caught up"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSm
                    font.weight: Theme.weightBold
                    color: Theme.foregroundDim
                }
            }
        }
    }
}
