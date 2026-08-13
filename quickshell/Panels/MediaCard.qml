// Full media card: album art, metadata, seekable progress, transport controls
// and a player picker when more than one MPRIS client is running.

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
    clip: true

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
    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        visible: Media.available
        spacing: Theme.spaceMd

        // Album art, or a fallback tile with the player glyph.
        ClippingRectangle {
            Layout.preferredWidth: 96
            Layout.preferredHeight: 96
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusSm
            color: Theme.surfaceDeep
            border.width: Theme.border
            border.color: Theme.outline

            Image {
                anchors.fill: parent
                source: Media.artUrl
                visible: Media.artUrl !== "" && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }

            Text {
                anchors.centerIn: parent
                visible: Media.artUrl === ""
                text: "󰎆"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXl + 8
                color: Theme.foregroundDim
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    Text {
                        Layout.fillWidth: true
                        text: Media.title !== "" ? Media.title : "Unknown track"
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontLg
                        font.weight: Theme.weightHeavy
                        color: Theme.foreground
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Media.artist !== "" ? Media.artist : Media.identity
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSm
                        color: Theme.foregroundDim
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: Media.album !== ""
                        text: Media.album
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontXs
                        color: Theme.foregroundDim
                        opacity: 0.8
                    }
                }

                BrixChip {
                    visible: Media.identity !== ""
                    text: Media.identity
                    accent: Theme.tertiary
                    Layout.alignment: Qt.AlignTop
                }
            }

            Item { Layout.fillHeight: true }

            // Seek bar with elapsed / total.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                Text {
                    text: Media.fmtTime(Media.position)
                    font.family: Theme.fontFamily
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
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontXs
                    font.weight: Theme.weightBold
                    color: Theme.foregroundDim
                }
            }

            // Transport.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spaceSm

                BrixIconButton {
                    icon: "󰒮"
                    size: 28
                    accent: Theme.surfaceAlt
                    enabled: Media.canGoPrevious
                    onClicked: Media.previous()
                }
                BrixIconButton {
                    icon: Media.playing ? "󰏤" : "󰐊"
                    size: 32
                    accent: Theme.primary
                    iconColor: Theme.onAccent
                    enabled: Media.canToggle
                    onClicked: Media.toggle()
                }
                BrixIconButton {
                    icon: "󰒭"
                    size: 28
                    accent: Theme.surfaceAlt
                    enabled: Media.canGoNext
                    onClicked: Media.next()
                }

                Item { Layout.fillWidth: true }

                // Player picker when several are present.
                Repeater {
                    model: Media.players.length > 1 ? Media.players : []

                    delegate: BrixButton {
                        id: playerBtn
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
}
