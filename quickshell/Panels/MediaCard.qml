// Full media card: album art, metadata, seekable progress, transport controls
// and a player picker when more than one MPRIS client is running.
//
// Laid out as a "now playing" column rather than art-beside-text. The card is
// stretched to the height of the control center's tallest column, and the earlier
// row layout pinned the metadata to the top and the transport to the bottom with a
// flexible spacer between them — which on a tall card produced a large dead gap
// through the middle. Here the artwork takes the slack instead: it is a centred
// square that grows into whatever space is left, so the card stays full at any
// height without anything being stranded.

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Theme
import qs.Components
import qs.Services

BrixCard {
    id: root

    radius: Theme.radiusMd
    color: Theme.surface
    shadowOffset: Theme.shadowSm

    // ── nothing playing ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: !Media.available
        spacing: Theme.spaceXs

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰝛"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXl + 6
            color: Theme.foregroundDim
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "no media player"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSm
            font.weight: Theme.weightBold
            color: Theme.foregroundDim
        }
    }

    // ── active player ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        visible: Media.available
        spacing: Theme.spaceSm

        // Which player this is, kept out of the way in the top-right corner.
        BrixChip {
            visible: Media.identity !== ""
            text: Media.identity
            accent: Theme.tertiary
            Layout.alignment: Qt.AlignRight
        }

        // Album art. The square is centred in whatever room the column has left,
        // so this is what absorbs a tall card rather than an empty spacer.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 72

            BrixCard {
                id: artFrame
                anchors.centerIn: parent
                // Cap it so a very tall card does not produce a comically large
                // cover; below the cap it tracks the smaller dimension.
                width: Math.max(72, Math.min(parent.width, parent.height, 190))
                height: width
                radius: Theme.radiusSm
                color: Theme.surfaceDeep
                shadowOffset: Theme.shadowSm

                // Inset by the border so the artwork sits inside the outline
                // rather than under it — Qt Quick's clip is rectangular, so a
                // full-bleed image would square off the rounded corners.
                ClippingRectangle {
                    anchors.fill: parent
                    anchors.margins: artFrame.border.width
                    radius: artFrame.radius - artFrame.border.width
                    color: "transparent"

                    Image {
                        anchors.fill: parent
                        source: Media.artUrl
                        visible: Media.artUrl !== "" && status === Image.Ready
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: Media.artUrl === ""
                    text: "󰎆"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontDisplay
                    color: Theme.foregroundDim
                }
            }
        }

        // ── metadata ────────────────────────────────────────────────────────
        Text {
            Layout.fillWidth: true
            text: Media.title !== "" ? Media.title : "Unknown track"
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontLg
            font.weight: Theme.weightHeavy
            color: Theme.foreground
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: -Theme.spaceXs
            text: Media.artist !== "" ? Media.artist : Media.identity
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSm
            font.weight: Theme.weightBold
            color: Theme.foregroundDim
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: -Theme.spaceXs
            visible: Media.album !== "" && Media.album !== Media.title
            text: Media.album
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontXs
            color: Theme.foregroundDim
            opacity: 0.75
        }

        // ── seek ────────────────────────────────────────────────────────────
        // Streams (YouTube Music through a browser, internet radio) report no
        // length, which rendered as "0:04 / 0:00" beside a slider pinned at zero
        // — it read as broken rather than as "not seekable". With no length there
        // is nothing to seek within, so show the elapsed time alone instead.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceXs
            visible: Media.length <= 0
            text: Media.fmtTime(Media.position)
            horizontalAlignment: Text.AlignHCenter
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontXs
            font.weight: Theme.weightBold
            color: Theme.foregroundDim
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceXs
            visible: Media.length > 0
            spacing: Theme.spaceSm

            Text {
                text: Media.fmtTime(Media.position)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
            }

            BrixSlider {
                Layout.fillWidth: true
                trackHeight: 10
                value: Media.progress
                accent: Theme.primary
                enabled: Media.canSeek
                onMoved: v => Media.seekTo(v)
            }

            Text {
                text: Media.fmtTime(Media.length)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
            }
        }

        // ── transport ───────────────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spaceMd

            BrixIconButton {
                icon: "󰒮"
                size: 30
                accent: Theme.surfaceAlt
                enabled: Media.canGoPrevious
                onClicked: Media.previous()
            }
            BrixIconButton {
                icon: Media.playing ? "󰏤" : "󰐊"
                size: 38
                accent: Theme.primary
                iconColor: Theme.onAccent
                enabled: Media.canToggle
                onClicked: Media.toggle()
            }
            BrixIconButton {
                icon: "󰒭"
                size: 30
                accent: Theme.surfaceAlt
                enabled: Media.canGoNext
                onClicked: Media.next()
            }
        }

        // Player picker, only when there is actually a choice to make.
        Flow {
            Layout.fillWidth: true
            visible: Media.players.length > 1
            spacing: Theme.spaceXs

            Repeater {
                model: Media.players.length > 1 ? Media.players : []

                delegate: BrixButton {
                    required property var modelData
                    text: modelData.identity
                    fontSize: 8
                    vPadding: 3
                    accent: Theme.surfaceAlt
                    active: Media.active === modelData
                    activeAccent: Theme.secondary
                    onClicked: Media.selectPlayer(modelData)
                }
            }
        }
    }
}
