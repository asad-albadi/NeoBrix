// ─────────────────────────────────────────────────────────────────────────────
//  The bar.
//
//  Three floating "islands" rather than one continuous strip — this is the most
//  recognisable part of the Neobrix layout. Each island is a BrixCard, so the
//  chunky outline and hard offset shadow come from the design system for free.
//
//  Left   : launcher · active window
//  Center : workspaces  (+ media island beside it while something is playing)
//  Right  : tray · indicators · clock  |  notifications
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Theme
import qs.Components
import qs.Services

PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barExclusive
    exclusiveZone: Theme.barExclusive
    color: "transparent"
    WlrLayershell.namespace: "neobrix-bar"
    WlrLayershell.layer: WlrLayer.Top

    readonly property var hyprMonitor: Hyprland.monitorFor(bar.screen)

    // ── left island ─────────────────────────────────────────────────────────
    BrixCard {
        id: leftIsland
        anchors.left: parent.left
        anchors.leftMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        height: Theme.barIslandHeight
        width: leftRow.implicitWidth + Theme.spaceMd * 2
        radius: Theme.radiusMd
        color: Theme.surfaceAlt
        shadowOffset: Theme.shadowMd

        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: Theme.spaceSm

            // Launcher / distro button — the accent-filled anchor of the bar.
            BrixIconButton {
                icon: "󰀻"
                size: Theme.barIslandHeight - Theme.spaceSm * 2
                radius: Theme.radiusSm
                // No nested shadow: it would be clipped by the island's border.
                shadowOffset: 0
                accent: Theme.primary
                active: Panels.isOpen("launcher")
                activeAccent: Theme.primary
                iconColor: Theme.onAccent
                tooltip: "Applications  ·  Super"
                onClicked: Panels.toggle("launcher")
                onRightClicked: Panels.toggle("session")
            }

            Rectangle {
                Layout.preferredWidth: Theme.border
                Layout.preferredHeight: 14
                color: Theme.outline
                opacity: 0.28
            }

            ActiveWindow {
                Layout.preferredWidth: implicitWidth
                maxWidth: Math.max(120, bar.width * 0.22)
            }
        }
    }

    // ── center: workspaces (+ media) ────────────────────────────────────────
    RowLayout {
        id: centerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        spacing: Theme.barGap

        BrixCard {
            Layout.preferredHeight: Theme.barIslandHeight
            Layout.preferredWidth: workspaces.implicitWidth + Theme.spaceMd * 2
            radius: Theme.radiusMd
            color: Theme.surfaceAlt
            shadowOffset: Theme.shadowMd

            Workspaces {
                id: workspaces
                anchors.centerIn: parent
                monitor: bar.hyprMonitor
            }
        }

        MediaPill {
            visible: Media.available
            Layout.preferredHeight: Theme.barIslandHeight
            Layout.preferredWidth: visible ? implicitWidth : 0
            maxTitleWidth: Math.max(80, bar.width * 0.14)
        }
    }

    // ── right islands ───────────────────────────────────────────────────────
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: Theme.barMargin
        anchors.top: parent.top
        anchors.topMargin: Theme.barMargin
        spacing: Theme.barGap

        BrixCard {
            Layout.preferredHeight: Theme.barIslandHeight
            Layout.preferredWidth: rightRow.implicitWidth + Theme.spaceMd * 2
            radius: Theme.radiusMd
            color: Theme.surfaceAlt
            shadowOffset: Theme.shadowMd

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: Theme.spaceMd

                Tray {
                    id: tray
                    Layout.preferredWidth: hasItems ? implicitWidth : 0
                }

                Rectangle {
                    visible: tray.hasItems
                    Layout.preferredWidth: visible ? Theme.border : 0
                    Layout.preferredHeight: 14
                    color: Theme.outline
                    opacity: 0.28
                }

                Indicators { Layout.preferredWidth: implicitWidth }

                // The bell lives in the segment with the other indicators now:
                // each of them opens its own control, so the island at the end
                // is free for the one button that still opens a whole panel.
                NotifButton { Layout.preferredWidth: implicitWidth }

                // Clock pill — the lavender chip from the Neobrix previews.
                ClockPill {}
            }
        }

        // Separate island, accent-filled as in the reference.
        BrixCard {
            Layout.preferredHeight: Theme.barIslandHeight
            Layout.preferredWidth: Theme.barIslandHeight
            radius: Theme.radiusMd
            color: Panels.isOpen("control") ? Theme.primary : Theme.pink
            shadowOffset: Theme.shadowMd

            ControlButton { anchors.centerIn: parent }
        }
    }
}
