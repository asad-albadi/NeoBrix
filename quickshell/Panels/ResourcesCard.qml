// CPU / RAM / swap / disk meters, temperature, and network throughput.
//
// Everything here moves. Temperature sits with them rather than in SpecsCard,
// where it was the one tile that changed while the rest never did.

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

        // Same reasoning as SpecsCard: the column stretches this card, and equal
        // spacers keep the meters centred instead of leaving dead space below
        // the last one.
        Item { Layout.fillHeight: true }

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
        Meter {
            // 100°C as full scale: it is the throttling point on every CPU this
            // runs on, so the bar reads as "how close to trouble" rather than
            // against an arbitrary maximum.
            visible: Hw.hasTemperature && SysInfo.temperature > 0
            label: "TEMP"
            glyph: "󰔏"
            accent: SysInfo.temperature >= 85 ? Theme.error
                  : SysInfo.temperature >= 70 ? Theme.warning : Theme.tertiary
            value: Math.max(0, Math.min(1, SysInfo.temperature / 100))
            detail: SysInfo.temperature.toFixed(0) + "°C"
        }

        // Throughput has no ceiling to draw a bar against, so it is read out
        // rather than metered.
        Readout {
            visible: Net.connected
            label: "NET"
            glyph: "󰛳"
            accent: Theme.primary
            down: SysInfo.fmtRate(SysInfo.netRxRate)
            up: SysInfo.fmtRate(SysInfo.netTxRate)
        }

        Item { Layout.fillHeight: true }
    }

    component Readout: RowLayout {
        id: readRoot
        property string label: ""
        property string glyph: ""
        property string down: ""
        property string up: ""
        property color accent: Theme.primary

        Layout.fillWidth: true
        spacing: Theme.spaceXs

        BrixCard {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            radius: Theme.radiusXs
            shadowOffset: 0
            color: readRoot.accent

            Text {
                anchors.centerIn: parent
                text: readRoot.glyph
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSm
                color: Theme.textOn(readRoot.accent)
            }
        }

        Text {
            Layout.preferredWidth: 34
            text: readRoot.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightHeavy
            color: Theme.foreground
        }

        Text {
            Layout.fillWidth: true
            text: "󰇚 " + readRoot.down
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightBold
            color: Theme.foregroundDim
        }

        Text {
            Layout.preferredWidth: 58
            horizontalAlignment: Text.AlignRight
            text: "󰕒 " + readRoot.up
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightBold
            color: Theme.foregroundDim
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
