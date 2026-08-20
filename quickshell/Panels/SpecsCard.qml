// "System Specs" — a grid of badge tiles, as in the Neobrix dashboard.
//
// Software above, hardware below. What is not here: uptime, which the middle
// column of the tab already carries; temperature and total memory, which
// ResourcesCard shows against what is actually in use.

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
        spacing: Theme.spaceSm

        SectionHeader { text: "SYSTEM SPECS"; icon: "󰇅"; Layout.fillWidth: true }

        // The card is stretched by the column it sits in (connectivity used to
        // take that slack before it became its own tab). Equal spacers above and
        // below centre the tiles in whatever height is left, so the leftover
        // reads as padding rather than as a hole under the last row.
        Item { Layout.fillHeight: true }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Theme.spaceXs
            columnSpacing: Theme.spaceXs

            Spec { label: "OS";     value: SysInfo.distro;    glyph: "󰣇"; accent: Theme.primary }
            Spec { label: "WM";     value: "Hyprland";        glyph: "󰖯"; accent: Theme.info }
            Spec { label: "KERNEL"; value: SysInfo.kernel;    glyph: "󰌽"; accent: Theme.tertiary }
            Spec { label: "SHELL";  value: SysInfo.shellName; glyph: "󰆍"; accent: Theme.secondary }
            Spec {
                // Spans, because it is the odd one out of the half-width tiles
                // and a hole beside it reads as something failing to load.
                Layout.columnSpan: 2
                label: "PACKAGES"
                value: SysInfo.packageCount > 0 ? String(SysInfo.packageCount) : "—"
                glyph: "󰏖"
                accent: Theme.warning
            }

            // Hardware. Each is absent rather than "—" when the probe found
            // nothing: a machine with no DMI model, or without pciutils for a
            // GPU name, should not be told about a tile it cannot fill.
            Spec {
                visible: SysInfo.cpuModel !== ""
                Layout.columnSpan: 2
                label: SysInfo.cpuThreads > 0 ? "CPU · " + SysInfo.cpuThreads + " THREADS" : "CPU"
                value: SysInfo.cpuModel
                glyph: "󰻠"
                accent: Theme.error
            }
            Spec {
                visible: SysInfo.gpuModel !== ""
                Layout.columnSpan: 2
                label: "GPU"
                value: SysInfo.gpuModel
                glyph: "󰢮"
                accent: Theme.info
            }
            Spec {
                visible: SysInfo.machineModel !== ""
                Layout.columnSpan: 2
                label: "MACHINE"
                value: SysInfo.machineModel
                glyph: "󰌢"
                accent: Theme.secondary
            }
        }

        Item { Layout.fillHeight: true }
    }

    component Spec: BrixCard {
        id: specRoot
        property string label: ""
        property string value: ""
        property string glyph: ""
        property color accent: Theme.primary

        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: Theme.radiusXs
        color: Theme.surfaceAlt
        shadowOffset: 0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.spaceXs
            anchors.rightMargin: Theme.spaceXs
            spacing: Theme.spaceXs

            BrixCard {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20
                radius: Theme.radiusXs
                shadowOffset: 0
                color: specRoot.accent

                Text {
                    anchors.centerIn: parent
                    text: specRoot.glyph
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSm
                    color: Theme.textOn(specRoot.accent)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                Text {
                    text: specRoot.label
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.weight: Theme.weightBold
                    font.letterSpacing: 0.5
                    color: Theme.foregroundDim
                }
                Text {
                    Layout.fillWidth: true
                    text: specRoot.value
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightBold
                    color: Theme.foreground
                }
            }
        }
    }
}
