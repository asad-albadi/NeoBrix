// On-screen level feedback for the volume / mic / brightness keybinds.
//
// Appears on the right edge for a moment whenever the corresponding value
// changes, then fades out. Suppressed on the first binding evaluation so it does
// not flash at login.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Theme
import qs.Components
import qs.Services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        // "volume" | "mic" | "backlight"
        property string kind: "volume"
        property bool showing: false
        property bool primed: false

        readonly property real level: kind === "mic" ? Audio.micVolume
                                    : kind === "backlight" ? Backlight.value
                                    : Audio.volume
        readonly property bool off: kind === "mic" ? Audio.micMuted
                                  : kind === "backlight" ? false
                                  : Audio.muted
        readonly property string glyph: kind === "mic" ? Audio.micIcon
                                      : kind === "backlight" ? "󰃠"
                                      : Audio.volumeIcon
        readonly property color accent: kind === "mic" ? Theme.secondary
                                      : kind === "backlight" ? Theme.warning
                                      : Theme.pink

        function flash(k) {
            if (!primed) return;          // ignore the initial binding pass
            win.kind = k;
            win.showing = true;
            hideTimer.restart();
        }

        // Prime after startup so initial property reads don't trigger an OSD.
        Timer {
            interval: 1500
            running: true
            onTriggered: win.primed = true
        }

        Connections {
            target: Audio
            function onVolumeChanged() { win.flash("volume"); }
            function onMutedChanged() { win.flash("volume"); }
            function onMicVolumeChanged() { win.flash("mic"); }
            function onMicMutedChanged() { win.flash("mic"); }
        }

        Connections {
            target: Backlight
            enabled: Hw.hasBacklight
            function onValueChanged() { win.flash("backlight"); }
        }

        Timer {
            id: hideTimer
            interval: 1400
            onTriggered: win.showing = false
        }

        visible: showing
        anchors { right: true }
        margins.right: Theme.spaceLg
        implicitWidth: 56
        implicitHeight: 200
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "neobrix-osd"
        // Purely informational — never take pointer input.
        mask: Region {}

        BrixCard {
            anchors.fill: parent
            anchors.margins: Theme.shadowMd
            radius: Theme.radiusMd
            color: Theme.surfaceAlt
            shadowOffset: Theme.shadowMd
            opacity: win.showing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spaceSm
                spacing: Theme.spaceSm

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Math.round(win.level * 100)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontMd
                    font.weight: Theme.weightHeavy
                    color: Theme.foreground
                }

                BrixVSlider {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    Layout.fillWidth: false
                    trackWidth: 28
                    value: win.level
                    accent: win.off ? Theme.surfaceDeep : win.accent
                    enabled: false
                }

                BrixCard {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.radiusXs
                    shadowOffset: 0
                    color: win.off ? Theme.surfaceDeep : win.accent

                    Text {
                        anchors.centerIn: parent
                        text: win.glyph
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontMd
                        color: Theme.onAccent
                    }
                }
            }
        }
    }
}
