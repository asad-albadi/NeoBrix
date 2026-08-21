// One network link, described and switchable.
//
// Both links get the same card so they read as siblings rather than as a main
// one and an afterthought, and so a row of them lines up: the height is fixed
// here rather than left to the content, because two cards side by side at
// different heights look like a mistake.
//
// Knows nothing about NetworkManager -- it is handed strings and a switch state
// and reports the switch being flipped, which keeps the wired and wireless
// wiring in ConnectivityTab where the rest of it lives.

import QtQuick
import QtQuick.Layouts
import qs.Theme
import qs.Components

// One link, described and switchable. Both cards are the same shape so the
// two links read as siblings rather than as a main one and an afterthought.
BrixCard {
    id: card

    property string glyph: ""
    property string title: ""
    property string detail: ""
    property string extra: ""
    property bool live: false        // this link is up and carrying traffic
    property bool isPrimary: false   // ...and it is the one being routed over
    property bool switchOn: false
    property string chipText: ""
    property color chipAccent: Theme.secondary
    signal switched(bool on)

    Layout.fillWidth: true
    Layout.preferredHeight: 66
    radius: Theme.radiusMd
    color: Theme.surface
    shadowOffset: Theme.shadowSm

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceSm

        BrixCard {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: Theme.radiusSm
            shadowOffset: Theme.shadowSm
            // Dim rather than red when down: a cable that is not plugged in
            // is not a fault, and neither is a radio switched off on purpose.
            color: card.live ? Theme.secondary : Theme.surfaceDeep

            Text {
                anchors.centerIn: parent
                text: card.glyph
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXl
                color: Theme.textOn(parent.color)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: card.title
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontLg
                font.weight: Theme.weightHeavy
                color: Theme.foreground
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.detail
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontXs
                font.weight: Theme.weightBold
                color: Theme.foregroundDim
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.extra
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 8
                color: Theme.foregroundDim
            }
        }

        // Only on the link actually being routed over, and only while it
        // is up: two cards both claiming FULL would say nothing.
        BrixChip {
            visible: card.chipText !== "" && card.isPrimary && card.live
            text: card.chipText
            accent: card.chipAccent
        }

        BrixToggle {
            checked: card.switchOn
            onToggled: on => card.switched(on)
        }
    }
}
