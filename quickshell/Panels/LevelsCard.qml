// Levels: output, microphone, screen brightness, and output device selection.
//
// Named for what it holds rather than for audio alone — the backlight row has
// always been in here, and a card labelled AUDIO with a brightness slider in it
// is a card that lies about one of its three rows.
//
// Reads and writes PipeWire node volumes directly. Rows for devices that do not
// exist are simply absent, and if PipeWire exposes neither a sink nor a
// backlight the card says so rather than showing sliders that do nothing.

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

        SectionHeader { text: "LEVELS"; icon: "󰘮"; Layout.fillWidth: true }

        Level {
            visible: Audio.hasSink
            Layout.fillWidth: true
            glyph: Audio.volumeIcon
            label: Audio.sinkName
            accent: Audio.muted ? Theme.surfaceDeep : Theme.pink
            value: Audio.volume
            onMoved: v => Audio.setVolume(v)
            onGlyphClicked: Audio.toggleMute()
        }

        Level {
            visible: Audio.hasSource
            Layout.fillWidth: true
            glyph: Audio.micIcon
            label: Audio.sourceName
            accent: Audio.micMuted ? Theme.surfaceDeep : Theme.secondary
            value: Audio.micVolume
            onMoved: v => Audio.setMicVolume(v)
            onGlyphClicked: Audio.toggleMicMute()
        }

        Level {
            visible: Hw.hasBacklight
            Layout.fillWidth: true
            glyph: "󰃠"
            label: "Backlight"
            accent: Theme.warning
            value: Backlight.value
            onMoved: v => Backlight.set(v)
        }

        Text {
            visible: !Audio.hasSink && !Audio.hasSource && !Hw.hasBacklight
            Layout.fillWidth: true
            text: "No audio devices are exposed by PipeWire on this machine."
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: 8
            color: Theme.foregroundDim
        }

        // Output picker — only interesting with more than one sink.
        Flow {
            visible: Audio.sinks.length > 1
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Repeater {
                model: Audio.sinks.length > 1 ? Audio.sinks : []

                delegate: BrixButton {
                    id: sinkBtn
                    required property var modelData
                    text: modelData.nickname || modelData.description || modelData.name
                    fontSize: 8
                    vPadding: 3
                    accent: Theme.surfaceAlt
                    active: Audio.sink === modelData
                    activeAccent: Theme.pink
                    onClicked: Audio.setDefaultSink(modelData)
                }
            }
        }
    }

    component Level: RowLayout {
        id: levelRoot
        property string glyph: ""
        property string label: ""
        property color accent: Theme.primary
        property real value: 0
        signal moved(real v)
        signal glyphClicked()

        spacing: Theme.spaceSm

        BrixIconButton {
            icon: levelRoot.glyph
            size: 24
            radius: Theme.radiusXs
            accent: levelRoot.accent
            iconColor: Theme.textOn(levelRoot.accent)
            onClicked: levelRoot.glyphClicked()
            onWheel: d => levelRoot.moved(Math.max(0, Math.min(1,
                        levelRoot.value + (d > 0 ? 0.05 : -0.05))))
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: levelRoot.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: Theme.foregroundDim
            }

            BrixSlider {
                Layout.fillWidth: true
                trackHeight: 12
                value: levelRoot.value
                accent: levelRoot.accent
                onMoved: v => levelRoot.moved(v)
            }
        }

        Text {
            Layout.preferredWidth: 30
            horizontalAlignment: Text.AlignRight
            text: Math.round(levelRoot.value * 100) + "%"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightBold
            color: Theme.foreground
        }
    }
}
