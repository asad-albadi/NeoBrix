// "System Specs" — a 2×3 grid of badge tiles, as in the Neobrix dashboard.

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

            Spec { label: "OS";    value: SysInfo.distro;   glyph: "󰣇"; accent: Theme.primary }
            Spec { label: "WM";    value: "Hyprland";       glyph: "󰖯"; accent: Theme.info }
            Spec { label: "KERNEL"; value: SysInfo.kernel;  glyph: "󰌽"; accent: Theme.tertiary }
            Spec { label: "SHELL"; value: SysInfo.shellName; glyph: "󰆍"; accent: Theme.secondary }
            Spec { label: "UPTIME"; value: SysInfo.uptimeText; glyph: "󰅐"; accent: Theme.pink }
            Spec {
                label: "PACKAGES"
                value: SysInfo.packageCount > 0 ? String(SysInfo.packageCount) : "—"
                glyph: "󰏖"
                accent: Theme.warning
            }
            Spec {
                visible: Hw.hasTemperature
                label: "TEMP"
                value: SysInfo.temperature > 0 ? SysInfo.temperature.toFixed(0) + "°C" : "—"
                glyph: "󰔏"
                accent: Theme.error
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
