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

    // A player can drop off the bus for a moment — browsers re-register their
    // MPRIS service on navigation, and Quickshell logs
    // "ServiceUnknown / The name is not activatable" when it polls one mid-flight.
    // Swapping straight to the empty state on that made the whole card, seek bar
    // included, blink out. Hold the last known player briefly instead, so a
    // transient dropout is invisible and only a real stop clears the card.
    property bool showPlayer: Media.available
    readonly property bool playerLive: Media.available

    onPlayerLiveChanged: {
        if (playerLive) {
            graceTimer.stop();
            showPlayer = true;
        } else {
            graceTimer.restart();
        }
    }

    Timer {
        id: graceTimer
        interval: 2500
        onTriggered: root.showPlayer = false
    }

    // ── nothing playing ─────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.showPlayer
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
        visible: root.showPlayer
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
        // Always present, even when the track reports no length. Streams
        // (YouTube Music in a browser, internet radio) omit mpris:length, and
        // hiding the row in that case made the control vanish entirely and the
        // card's layout jump between tracks that do and do not report one.
        // Showing "--:--" for an unknown total is honest without implying a
        // zero-length track, which is what a bare "0:00" did.
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Theme.spaceXs
            spacing: Theme.spaceSm

            Text {
                text: Media.fmtTime(Media.position)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
            }

            // Seekable: a real slider with a draggable handle.
            BrixSlider {
                Layout.fillWidth: true
                visible: Media.canSeek && Media.length > 0
                trackHeight: 10
                value: Media.progress
                accent: Theme.primary
                onMoved: v => Media.seekTo(v)
            }

            // Not seekable: a plain meter, not a faded slider. BrixSlider drops
            // to 45% opacity when disabled, which on a stream (no mpris:length,
            // so nothing to seek within) left the bar looking washed out and
            // half-broken — and this design rejects transparency as a state cue
            // anyway. A handle-less meter at full opacity says "position only,
            // not draggable" without dimming anything.
            BrixProgress {
                Layout.fillWidth: true
                visible: !(Media.canSeek && Media.length > 0)
                implicitHeight: 10
                value: Media.progress
                accent: Theme.primary
            }

            Text {
                text: Media.length > 0 ? Media.fmtTime(Media.length) : "--:--"
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
                opacity: Media.length > 0 ? 1.0 : 0.6
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
