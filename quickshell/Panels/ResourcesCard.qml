// CPU / RAM / disk meters.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

BrixCard {
    id: root

    implicitHeight: layout.implicitHeight + Theme.spaceSm * 2
    radius: Theme.radiusMd
    color: Theme.surface
    shadowOffset: Theme.shadowSm

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceXs

        SectionHeader { text: "RESOURCES"; icon: "󰄨"; Layout.fillWidth: true }

        Meter {
            label: "CPU"
            glyph: "󰻠"
            accent: Theme.error
            value: SysInfo.cpuUsage
            detail: Math.round(SysInfo.cpuUsage * 100) + "%"
        }
        Meter {
            label: "RAM"
            glyph: "󰍛"
            accent: Theme.info
            value: SysInfo.memUsage
            detail: SysInfo.memUsedGiB.toFixed(1) + "/" + SysInfo.memTotalGiB.toFixed(1) + "G"
        }
        Meter {
            visible: SysInfo.swapUsage > 0
            label: "SWAP"
            glyph: "󰓡"
            accent: Theme.tertiary
            value: SysInfo.swapUsage
            detail: Math.round(SysInfo.swapUsage * 100) + "%"
        }
        Meter {
            label: "DISK"
            glyph: "󰋊"
            accent: Theme.secondary
            value: SysInfo.diskUsage
            detail: SysInfo.diskUsedGiB.toFixed(0) + "/" + SysInfo.diskTotalGiB.toFixed(0) + "G"
        }
    }

    component Meter: RowLayout {
        id: meterRoot
        property string label: ""
        property string glyph: ""
        property string detail: ""
        property color accent: Theme.primary
        property real value: 0

        Layout.fillWidth: true
        spacing: Theme.spaceXs

        BrixCard {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: Theme.radiusXs
            shadowOffset: 0
            color: meterRoot.accent

            Text {
                anchors.centerIn: parent
                text: meterRoot.glyph
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                color: Theme.textOn(meterRoot.accent)
            }
        }

        Text {
            Layout.preferredWidth: 34
            text: meterRoot.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightHeavy
            color: Theme.foreground
        }

        BrixProgress {
            Layout.fillWidth: true
            Layout.preferredHeight: 11
            value: meterRoot.value
            accent: meterRoot.accent
        }

        Text {
            Layout.preferredWidth: 58
            horizontalAlignment: Text.AlignRight
            text: meterRoot.detail
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightBold
            color: Theme.foregroundDim
        }
    }
}
