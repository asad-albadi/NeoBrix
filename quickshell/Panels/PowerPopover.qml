// Power control, hanging under the battery glyph: charge, and the profile the
// machine runs at.
//
// power-profiles-daemon is in the package list and nothing in the shell spoke to
// it until now — the profile could only be changed from a terminal.
// Quickshell exposes it natively, so this is a property write, not a
// powerprofilesctl spawn.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.Theme
import qs.Components
import qs.Services

BrixPopup {
    id: root

    panel: "power"
    alignment: "topAnchor"
    scrimEnabled: false
    anchorX: Panels.popoverAnchorX
    contentWidth: 286
    contentHeight: Hw.hasBattery ? 176 : 122

    readonly property var battery: UPower.displayDevice
    readonly property bool charging:
        battery && (battery.state === UPowerDeviceState.Charging
                    || battery.state === UPowerDeviceState.FullyCharged)

    // timeToEmpty/timeToFull are seconds, and are 0 while the daemon has not
    // worked out a rate yet — which is most of the first minute after plugging
    // in. Showing "0m remaining" then would be worse than showing nothing.
    function duration(secs) {
        if (!secs || secs <= 0) return "";
        const h = Math.floor(secs / 3600);
        const m = Math.round((secs % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusLg
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            // ── battery ─────────────────────────────────────────────────────
            SectionHeader {
                visible: Hw.hasBattery
                text: "BATTERY"
                icon: "󰁹"
                Layout.fillWidth: true
            }

            RowLayout {
                visible: Hw.hasBattery
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                Text {
                    text: root.battery
                          ? Math.round(root.battery.percentage * 100) + "%" : "—"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.weightHeavy
                    color: root.battery && root.battery.percentage < 0.15
                           ? Theme.error : Theme.foreground
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    Text {
                        Layout.fillWidth: true
                        text: root.charging ? "charging" : "on battery"
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Theme.weightBold
                        color: Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.battery) return "";
                            const d = root.charging
                                      ? root.duration(root.battery.timeToFull)
                                      : root.duration(root.battery.timeToEmpty);
                            if (d === "") return "estimating…";
                            return root.charging ? d + " to full" : d + " remaining";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        color: Theme.foregroundDim
                    }
                }
            }

            BrixProgress {
                visible: Hw.hasBattery
                Layout.fillWidth: true
                value: root.battery ? root.battery.percentage : 0
                accent: root.battery && root.battery.percentage < 0.15
                        ? Theme.error : Theme.primary
            }

            // ── profile ─────────────────────────────────────────────────────
            SectionHeader { text: "PROFILE"; icon: "󰓅"; Layout.fillWidth: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceXs

                Profile {
                    label: "SAVER"
                    glyph: "󰾆"
                    profile: PowerProfile.PowerSaver
                }
                Profile {
                    label: "BALANCED"
                    glyph: "󰾅"
                    profile: PowerProfile.Balanced
                }
                Profile {
                    // Absent on machines whose firmware offers no performance
                    // profile, rather than shown as a button that silently does
                    // nothing when pressed.
                    visible: PowerProfiles.hasPerformanceProfile
                    label: "PERF"
                    glyph: "󰓅"
                    profile: PowerProfile.Performance
                }
            }

            Text {
                visible: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
                Layout.fillWidth: true
                text: "performance is being held back — " + (
                    PowerProfiles.degradationReason === PerformanceDegradationReason.LapDetected
                    ? "lap mode" : "high temperature")
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: Theme.warning
            }

            Item { Layout.fillHeight: true }
        }
    }

    component Profile: Item {
        id: pRoot
        property string label: ""
        property string glyph: ""
        property int profile: PowerProfile.Balanced

        readonly property bool active: PowerProfiles.profile === pRoot.profile

        Layout.fillWidth: true
        implicitHeight: 38

        BrixCard {
            anchors.fill: parent
            radius: Theme.radiusSm
            color: pRoot.active ? Theme.primary
                 : pMouse.containsMouse ? Theme.surfaceDeep : Theme.surface
            border.width: pRoot.active ? Theme.borderThick : Theme.border
            shadowOffset: pMouse.pressed ? 0 : Theme.shadowSm
            x: pMouse.pressed ? Theme.shadowSm : 0
            y: pMouse.pressed ? Theme.shadowSm : 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: -2

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: pRoot.glyph
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMd
                    color: pRoot.active ? Theme.onAccent : Theme.foreground
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: pRoot.label
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.weight: Theme.weightBold
                    color: pRoot.active ? Theme.onAccent : Theme.foregroundDim
                }
            }
        }

        MouseArea {
            id: pMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: PowerProfiles.profile = pRoot.profile
        }
    }
}
