// Compact now-playing island — appears only while an MPRIS player exists.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Theme
import qs.Components
import qs.Services

Item {
    id: root

    property int maxTitleWidth: 150

    implicitWidth: row.implicitWidth + Theme.spaceMd * 2
    implicitHeight: Theme.barIslandHeight

    BrixCard {
        anchors.fill: parent
        radius: Theme.radiusMd
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowSm
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.spaceSm

        Text {
            text: Media.playing ? "󰎈" : "󰏤"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMd
            color: Media.playing ? Theme.foreground : Theme.foregroundDim
        }

        Text {
            Layout.maximumWidth: root.maxTitleWidth
            text: Media.title !== ""
                  ? (Media.artist !== "" ? Media.title + "  ·  " + Media.artist : Media.title)
                  : Media.identity
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSm
            font.weight: Theme.weightBold
            color: Theme.foreground
        }

        Rectangle {
            Layout.preferredWidth: Theme.border
            Layout.preferredHeight: 14
            color: Theme.outline
            opacity: 0.4
        }

        Ctl { glyph: "󰒮"; enabled: Media.canGoPrevious; onActivated: Media.previous() }
        Ctl {
            glyph: Media.playing ? "󰏤" : "󰐊"
            enabled: Media.canToggle
            onActivated: Media.toggle()
        }
        Ctl { glyph: "󰒭"; enabled: Media.canGoNext; onActivated: Media.next() }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Panels.openControl("system")
    }

    component Ctl: Item {
        id: ctl
        property string glyph: ""
        property bool enabled: true
        signal activated()

        implicitWidth: 16
        implicitHeight: 16
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        opacity: enabled ? (ctlMouse.containsMouse ? 0.6 : 1) : 0.3

        Text {
            anchors.centerIn: parent
            text: ctl.glyph
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontMd
            color: Theme.foreground
        }

        MouseArea {
            id: ctlMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: ctl.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ctl.activated()
        }
    }
}
