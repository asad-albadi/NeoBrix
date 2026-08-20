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
                // Spans the grid, so there is room to say where they came from
                // rather than only how many there are. Each source appears only
                // if it has anything in it: no flatpak runtime, no flatpak
                // count, and a machine with nothing from the AUR does not need
                // telling that it has none.
                Layout.columnSpan: 2
                label: "PACKAGES"
                value: {
                    if (SysInfo.packageCount <= 0) return "—";
                    const from = [];
                    if (SysInfo.packageNative > 0) from.push(SysInfo.packageNative + " repo");
                    if (SysInfo.packageForeign > 0) from.push(SysInfo.packageForeign + " AUR");
                    if (SysInfo.packageFlatpak > 0) from.push(SysInfo.packageFlatpak + " flatpak");
                    return from.length > 0
                           ? SysInfo.packageCount + "  ·  " + from.join(" · ")
                           : String(SysInfo.packageCount);
                }
                glyph: "󰏖"
                accent: Theme.warning
            }

            // Hardware. Each is absent rather than "—" when the probe found
            // nothing: a machine with no DMI model, or without pciutils for a
            // GPU name, should not be told about a tile it cannot fill.
            Spec {
                visible: SysInfo.cpuModel !== ""
                Layout.columnSpan: 2
                label: {
                    const p = [];
                    if (SysInfo.cpuCores > 0)
                        p.push(SysInfo.cpuCores + (SysInfo.cpuCores === 1 ? " CORE" : " CORES"));
                    // Only when they differ: "4 CORES · 4 THREADS" on a chip
                    // without SMT says the same thing twice.
                    if (SysInfo.cpuThreads > SysInfo.cpuCores)
                        p.push(SysInfo.cpuThreads + " THREADS");
                    // Base to boost, rather than one number that reads as the
                    // current clock when it is nothing of the sort.
                    if (SysInfo.cpuMaxGHz > 0)
                        p.push(SysInfo.cpuBaseGHz > 0 && SysInfo.cpuBaseGHz < SysInfo.cpuMaxGHz
                               ? SysInfo.cpuBaseGHz.toFixed(1) + "–"
                                 + SysInfo.cpuMaxGHz.toFixed(1) + " GHZ"
                               : SysInfo.cpuMaxGHz.toFixed(1) + " GHZ");
                    return p.length > 0 ? "CPU · " + p.join(" · ") : "CPU";
                }
                value: SysInfo.cpuModel
                glyph: "󰻠"
                accent: Theme.error
            }
            Spec {
                visible: SysInfo.gpuModel !== ""
                Layout.columnSpan: 2
                label: SysInfo.gpuMemoryMiB > 0
                       ? "GPU · " + Math.round(SysInfo.gpuMemoryMiB / 1024) + " GB"
                       : "GPU"
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
