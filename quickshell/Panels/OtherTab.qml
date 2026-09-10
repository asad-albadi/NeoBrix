import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Components
import qs.Services

Item {
    ColumnLayout {
        anchors.fill: parent; spacing: Theme.spaceMd
        Text { text: "OTHER SETTINGS"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontLg; font.weight: Theme.weightHeavy; color: Theme.foreground }
        BrixCard {
            Layout.fillWidth: true; radius: Theme.radiusMd; color: Theme.surface; shadowOffset: Theme.shadowSm
            ColumnLayout { anchors.fill: parent; anchors.margins: Theme.spaceMd; spacing: Theme.spaceSm
                Text { text: "PER-MONITOR WORKSPACES"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontMd; font.weight: Theme.weightHeavy; color: Theme.foreground }
                Text { Layout.fillWidth: true; text: "Each display receives its own local workspace set. Workspace keys, scrolling and the bar follow the focused display."; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: Theme.fontXs; font.weight: Theme.weightBold; color: Theme.foregroundDim }
                RowLayout { Layout.fillWidth: true
                    BrixButton { text: WorkspaceMode.enabled ? "ON" : "OFF"; icon: "󰔡"; active: WorkspaceMode.enabled; activeAccent: Theme.primary; accent: Theme.surfaceAlt; onClicked: WorkspaceMode.setEnabled(!WorkspaceMode.enabled) }
                    Item { Layout.fillWidth: true }
                    Text { text: "SPACES PER DISPLAY"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontXs; font.weight: Theme.weightHeavy; color: Theme.foregroundDim }
                    BrixSelect { Layout.preferredWidth: 82; options: [3,5,10]; value: WorkspaceMode.spaces; onPicked: value => WorkspaceMode.setSpaces(value) }
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
    Component.onCompleted: WorkspaceMode.refresh()
}
